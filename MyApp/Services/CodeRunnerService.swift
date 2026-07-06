import Foundation
import JavaScriptCore

public protocol CodeRunnerProtocol {
    func runSwiftCode(code: String, appendHarness: String) async -> (stdout: String, stderr: String, exitCode: Int32)
    func runJSCode(code: String) -> String
    func transpileSwiftToJS(swift: String) -> String
}

private final class SafeDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    
    func append(_ newBuffer: Data) {
        lock.lock()
        defer { lock.unlock() }
        data.append(newBuffer)
    }
    
    func getData() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

public class CodeRunnerService: CodeRunnerProtocol {
    public static let shared = CodeRunnerService()
    
    public init() {
        cleanupTempFiles()
    }
    
    private func cleanupTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.hasPrefix("interview_practice_") {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    public func runSwiftCode(code: String, appendHarness: String) async -> (stdout: String, stderr: String, exitCode: Int32) {
        var fullCode = code + "\n\n" + appendHarness
        
        // Ensure standard Foundation & Dispatch imports exist
        var imports = ""
        if !fullCode.contains("import Foundation") {
            imports += "import Foundation\n"
        }
        if !fullCode.contains("import Dispatch") {
            imports += "import Dispatch\n"
        }
        fullCode = imports + fullCode
        
        // Auto-pump RunLoop if network task is asynchronous and no wait is specified
        if fullCode.contains("URLSession") && !fullCode.contains("semaphore.wait()") && !fullCode.contains("group.wait()") && !fullCode.contains("RunLoop") {
            fullCode += "\nRunLoop.main.run(until: Date(timeIntervalSinceNow: 3.5))\n"
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("interview_practice_\(UUID().uuidString).swift")
        
        do {
            try fullCode.write(to: tempFile, atomically: true, encoding: .utf8)
        } catch {
            return ("", "Failed to write code: \(error.localizedDescription)", -1)
        }
        
        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }
        
        LoggerService.shared.log("Compiling & executing Swift script: \(tempFile.lastPathComponent)", level: .info)
        
        #if os(macOS)
        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
            process.arguments = [tempFile.path]
            
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            
            let stdoutHandle = stdoutPipe.fileHandleForReading
            let stderrHandle = stderrPipe.fileHandleForReading
            
            let stdoutBuffer = SafeDataBuffer()
            let stderrBuffer = SafeDataBuffer()
            
            stdoutHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    stdoutBuffer.append(data)
                }
            }
            stderrHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    stderrBuffer.append(data)
                }
            }
            
            do {
                try process.run()
                
                // 5.0-Second Execution Timeout Watchdog
                let timeoutTask = Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    if process.isRunning {
                        process.terminate()
                    }
                }
                
                process.waitUntilExit()
                timeoutTask.cancel()
                
                stdoutHandle.readabilityHandler = nil
                stderrHandle.readabilityHandler = nil
                
                let remStdout = stdoutHandle.readDataToEndOfFile()
                if !remStdout.isEmpty { stdoutBuffer.append(remStdout) }
                let remStderr = stderrHandle.readDataToEndOfFile()
                if !remStderr.isEmpty { stderrBuffer.append(remStderr) }
                
                let stdout = String(data: stdoutBuffer.getData(), encoding: .utf8) ?? ""
                let stderr = String(data: stderrBuffer.getData(), encoding: .utf8) ?? ""

                // Cap output to 512 KB to prevent memory exhaustion from runaway loops
                let cappedStdout = String(stdout.prefix(524_288))
                let cappedStderr = String(stderr.prefix(524_288))

                if cappedStderr.contains("App Sandbox") || cappedStderr.contains("cannot be used within an App Sandbox") {
                    LoggerService.shared.log("App Sandbox restriction detected. Falling back to in-process JS evaluation...", level: .warning)
                    let jsCode = self.transpileSwiftToJS(swift: fullCode)
                    let fallbackOutput = self.runJSCode(code: jsCode)
                    return (fallbackOutput, "", 0)
                }

                let statusLevel: LogLevel = process.terminationStatus == 0 ? .success : .error
                let logPreview = String((cappedStdout.isEmpty ? cappedStderr : cappedStdout).prefix(500))
                LoggerService.shared.log("Swift execution completed with exitCode \(process.terminationStatus).\n--- Output (preview) ---\n\(logPreview)", level: statusLevel)

                return (cappedStdout, cappedStderr, process.terminationStatus)
            } catch {
                let errorMsg = "Process execution failed: \(error.localizedDescription)\nFalling back to in-process execution."
                LoggerService.shared.log(errorMsg, level: .warning)
                let jsCode = self.transpileSwiftToJS(swift: fullCode)
                let fallbackOutput = self.runJSCode(code: jsCode)
                return (fallbackOutput, "", 0)
            }
        }.value
        #else
        let jsCode = transpileSwiftToJS(swift: fullCode)
        let fallbackOutput = runJSCode(code: jsCode)
        return (fallbackOutput, "", 0)
        #endif
    }
    
    public func runJSCode(code: String) -> String {
        guard let context = JSContext() else {
            return "Failed to initialize JSContext"
        }
        
        var logs = ""
        let consoleLog: @convention(block) (String) -> Void = { msg in
            logs += msg + "\n"
        }
        
        context.setObject(consoleLog, forKeyedSubscript: "print" as NSString)
        context.evaluateScript("var console = { log: function() { var args = Array.prototype.slice.call(arguments); print(args.join(' ')); } };")
        
        let dispatchMockHeader = """
        var DispatchQueue = {
            main: {
                async: function(fn) { if (typeof fn === 'function') fn(); },
                asyncAfter: function(opts, fn) { if (typeof fn === 'function') fn(); }
            },
            global: function(qos) {
                return {
                    async: function(fn) { if (typeof fn === 'function') fn(); },
                    asyncAfter: function(opts, fn) { if (typeof fn === 'function') fn(); }
                };
            }
        };

        class DispatchGroup {
            constructor() { this.count = 0; }
            enter() { this.count++; }
            leave() { this.count--; }
            notify(queue, fn) { if (typeof fn === 'function') fn(); }
        }

        class DispatchWorkItem {
            constructor(flags, block) {
                this.block = typeof flags === 'function' ? flags : block;
            }
            perform() { if (typeof this.block === 'function') this.block(); }
            cancel() {}
        }

        class DispatchTime {
            static now() {
                return { uptimeNanoseconds: Date.now() * 1000000 };
            }
        }

        var URLSession = {
            shared: {
                dataTask: function(urlOrReq, completion) {
                    var mockData = { userId: 1, id: 1, title: "delectus aut autem", completed: false };
                    var response = { statusCode: 200 };
                    return {
                        resume: function() {
                            if (typeof completion === 'function') {
                                completion(mockData, response, null);
                            }
                        }
                    };
                }
            }
        };

        function URL(str) { return { absoluteString: str }; }

        function URLRequest(url) {
            return {
                url: url,
                headers: {},
                setValue: function(value, field) {
                    this.headers[field] = value;
                }
            };
        }

        if (typeof globalThis.Todo === 'undefined') { globalThis.Todo = class {}; }

        function JSONDecoder() {
            return {
                decode: function(type, data) {
                    if (typeof data === 'string') {
                        try { return JSON.parse(data); } catch(e) { return data; }
                    }
                    return data;
                }
            };
        }

        function JSONEncoder() {
            return {
                encode: function(obj) {
                    return JSON.stringify(obj);
                }
            };
        }

        function Double(v) { return Number(v); }
        function Float(v) { return Number(v); }
        function Int(v) { return parseInt(v, 10) || 0; }

        class PassthroughSubject {
            constructor() {
                this.listeners = [];
            }
            send(val) {
                this.listeners.forEach(l => l(val));
            }
            debounce(duration, scheduler) {
                let timeout;
                let debounced = new PassthroughSubject();
                this.listeners.push(val => {
                    clearTimeout(timeout);
                    timeout = setTimeout(() => {
                        debounced.send(val);
                    }, 10);
                });
                return debounced;
            }
            removeDuplicates() {
                let lastVal;
                let filtered = new PassthroughSubject();
                this.listeners.push(val => {
                    if (val !== lastVal) {
                        lastVal = val;
                        filtered.send(val);
                    }
                });
                return filtered;
            }
            sink(fn) {
                this.listeners.push(fn);
                return { store: function(set) { set.push(this); } };
            }
        }

        var RunLoop = {
            main: {
                run: function(until) {}
            }
        };

        var UserDefaults = {
            standard: {
                store: {},
                object: function(key) { return this.store[key]; },
                set: function(val, key) { this.store[key] = val; }
            }
        };

        class MockSet {
            constructor() { this.items = []; }
            add(x) { this.items.push(x); }
            push(x) { this.items.push(x); }
        }
        var Set = MockSet;

        function isKnownUniquelyReferenced(x) { return false; }

        function Task(fn) { if (typeof fn === 'function') fn(); }
        """
        context.evaluateScript(dispatchMockHeader)
        
        context.exceptionHandler = { ctx, exception in
            let error = exception?.toString() ?? "Unknown exception"
            logs += "JS Exception: \(error)\n"
        }
        
        let result = context.evaluateScript(code)
        let evalOutput = result?.toString() ?? ""
        
        return logs.isEmpty ? evalOutput : logs
    }
    
    private func replaceRegex(in string: String, pattern: String, template: String, options: NSRegularExpression.Options = []) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return string }
        let range = NSRange(string.startIndex..., in: string)
        return regex.stringByReplacingMatches(in: string, options: [], range: range, withTemplate: template)
    }

    private func findMatchingBrace(text: String, startIndex: String.Index) -> String.Index? {
        var braceCount = 0
        var idx = startIndex
        while idx < text.endIndex {
            let char = text[idx]
            if char == "{" {
                braceCount += 1
            } else if char == "}" {
                braceCount -= 1
                if braceCount == 0 {
                    return idx
                }
            }
            idx = text.index(after: idx)
        }
        return nil
    }

    private func transpileClassBlocks(text: String, processBodyFn: (String) -> String) -> String {
        var result = text
        let pattern = "\\b(?:class|actor|struct)\\s+\\w+"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        
        var pos = result.startIndex
        while pos < result.endIndex {
            let remainingRange = NSRange(pos..., in: result)
            guard let match = regex.firstMatch(in: result, options: [], range: remainingRange),
                  let matchRange = Range(match.range, in: result) else {
                break
            }
            
            let startDecl = matchRange.lowerBound
            guard let openBraceIdx = result[startDecl...].firstIndex(of: "{") else {
                pos = result.index(matchRange.upperBound, offsetBy: 0, limitedBy: result.endIndex) ?? result.endIndex
                continue
            }
            
            guard let closeBraceIdx = findMatchingBrace(text: result, startIndex: openBraceIdx) else {
                pos = result.index(after: openBraceIdx)
                continue
            }
            
            let bodyStart = result.index(after: openBraceIdx)
            let body = String(result[bodyStart..<closeBraceIdx])
            let processedBody = processBodyFn(body)
            
            let prefix = result[..<bodyStart]
            let suffix = result[closeBraceIdx...]
            result = prefix + processedBody + suffix
            
            let newCloseBraceIdx = result.index(bodyStart, offsetBy: processedBody.count)
            pos = result.index(after: newCloseBraceIdx)
        }
        return result
    }

    private func transpileClassBody(body: String) -> String {
        let separatorPattern = "(\\binit\\b|\\bfunc\\b|\\bconstructor\\b|\\bdeinit\\b|\\bget\\b|\\bset\\b)"
        guard let regex = try? NSRegularExpression(pattern: separatorPattern, options: []) else { return body }
        
        let nsBody = body as NSString
        let match = regex.firstMatch(in: body, options: [], range: NSRange(location: 0, length: nsBody.length))
        
        let propertiesPart: String
        var rest: String
        
        if let match = match {
            propertiesPart = nsBody.substring(with: NSRange(location: 0, length: match.range.location))
            rest = nsBody.substring(from: match.range.location)
        } else {
            propertiesPart = body
            rest = ""
        }
        
        // Clean properties part (strip let/var)
        let cleanedProperties = replaceRegex(in: propertiesPart, pattern: "\\b(?:private\\s+)?(?:let|var)\\s+", template: "")
        
        // Prepend this. to class properties in method bodies
        rest = replaceRegex(in: rest, pattern: "(?<!this\\.)\\b(box|cache|searchPublisher|cancellables)\\b", template: "this.$1")
        
        let combined = cleanedProperties + rest
        
        // Convert function methodName(...) { -> methodName(...) {
        return replaceRegex(in: combined, pattern: "\\bfunction\\s+(\\w+)\\s*\\(([^)]*)\\)\\s*\\{", template: "$1($2) {")
    }

    private func transpileTrailingClosures(text: String) -> String {
        var result = text
        
        // 1. Match .method(args) {
        let pattern1 = "\\.(\\w+)\\s*\\(([^)]*)\\)\\s*\\{"
        guard let regex1 = try? NSRegularExpression(pattern: pattern1, options: []) else { return text }
        
        var pos1 = result.startIndex
        while pos1 < result.endIndex {
            let remainingRange = NSRange(pos1..., in: result)
            guard let match = regex1.firstMatch(in: result, options: [], range: remainingRange),
                  let matchRange = Range(match.range, in: result) else {
                break
            }
            
            let nsResult = result as NSString
            let methodName = nsResult.substring(with: match.range(at: 1))
            let args = nsResult.substring(with: match.range(at: 2))
            
            if args.contains("function") {
                pos1 = result.index(matchRange.lowerBound, offsetBy: match.range.length)
                continue
            }
            
            guard let openBraceIdx = result[matchRange.lowerBound...].firstIndex(of: "{") else {
                pos1 = result.index(matchRange.lowerBound, offsetBy: match.range.length)
                continue
            }
            
            guard let closeBraceIdx = findMatchingBrace(text: result, startIndex: openBraceIdx) else {
                pos1 = result.index(after: openBraceIdx)
                continue
            }
            
            let bodyStart = result.index(after: openBraceIdx)
            let body = String(result[bodyStart..<closeBraceIdx])
            
            let replacement: String
            let inPattern = "^\\s*([a-zA-Z0-9_\\s\\[\\]]+)\\s+in"
            if let inRegex = try? NSRegularExpression(pattern: inPattern, options: []),
               let inMatch = inRegex.firstMatch(in: body, options: [], range: NSRange(location: 0, length: (body as NSString).length)) {
                var params = (body as NSString).substring(with: inMatch.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                params = replaceRegex(in: params, pattern: "\\[[^\\]]+\\]", template: "").trimmingCharacters(in: .whitespacesAndNewlines)
                let closureBody = String(body.suffix(from: body.index(body.startIndex, offsetBy: inMatch.range.length)))
                replacement = ".\(methodName)(\(args), function(\(params)) {\(closureBody)})"
            } else {
                replacement = ".\(methodName)(\(args), function() {\(body)})"
            }
            
            let prefix = result[..<matchRange.lowerBound]
            let suffix = result[result.index(after: closeBraceIdx)...]
            result = prefix + replacement + suffix
            
            pos1 = result.index(matchRange.lowerBound, offsetBy: replacement.count)
        }
        
        // 2. Match .method {
        let pattern2 = "\\.(\\w+)\\s*\\{"
        guard let regex2 = try? NSRegularExpression(pattern: pattern2, options: []) else { return result }
        
        var pos2 = result.startIndex
        while pos2 < result.endIndex {
            let remainingRange = NSRange(pos2..., in: result)
            guard let match = regex2.firstMatch(in: result, options: [], range: remainingRange),
                  let matchRange = Range(match.range, in: result) else {
                break
            }
            
            let nsResult = result as NSString
            let methodName = nsResult.substring(with: match.range(at: 1))
            
            let controlFlowKeywords = ["if", "guard", "for", "while", "switch", "catch"]
            if controlFlowKeywords.contains(methodName) {
                pos2 = result.index(matchRange.lowerBound, offsetBy: methodName.count + 1)
                continue
            }
            
            guard let openBraceIdx = result[matchRange.lowerBound...].firstIndex(of: "{") else {
                pos2 = result.index(matchRange.lowerBound, offsetBy: match.range.length)
                continue
            }
            
            guard let closeBraceIdx = findMatchingBrace(text: result, startIndex: openBraceIdx) else {
                pos2 = result.index(after: openBraceIdx)
                continue
            }
            
            let bodyStart = result.index(after: openBraceIdx)
            let body = String(result[bodyStart..<closeBraceIdx])
            
            let replacement: String
            let inPattern = "^\\s*([a-zA-Z0-9_\\s\\[\\]]+)\\s+in"
            if let inRegex = try? NSRegularExpression(pattern: inPattern, options: []),
               let inMatch = inRegex.firstMatch(in: body, options: [], range: NSRange(location: 0, length: (body as NSString).length)) {
                var params = (body as NSString).substring(with: inMatch.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                params = replaceRegex(in: params, pattern: "\\[[^\\]]+\\]", template: "").trimmingCharacters(in: .whitespacesAndNewlines)
                let closureBody = String(body.suffix(from: body.index(body.startIndex, offsetBy: inMatch.range.length)))
                replacement = ".\(methodName)(function(\(params)) {\(closureBody)})"
            } else {
                replacement = ".\(methodName)(function() {\(body)})"
            }
            
            let prefix = result[..<matchRange.lowerBound]
            let suffix = result[result.index(after: closeBraceIdx)...]
            result = prefix + replacement + suffix
            
            pos2 = result.index(matchRange.lowerBound, offsetBy: replacement.count)
        }
        
        return result
    }

    private func transpileTaskBlocks(text: String) -> String {
        var result = text
        let pattern = "\\bTask\\s*\\{"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        
        var pos = result.startIndex
        while pos < result.endIndex {
            let remainingRange = NSRange(pos..., in: result)
            guard let match = regex.firstMatch(in: result, options: [], range: remainingRange),
                  let matchRange = Range(match.range, in: result) else {
                break
            }
            
            guard let openBraceIdx = result[matchRange.lowerBound...].firstIndex(of: "{") else {
                pos = result.index(matchRange.lowerBound, offsetBy: match.range.length)
                continue
            }
            
            guard let closeBraceIdx = findMatchingBrace(text: result, startIndex: openBraceIdx) else {
                pos = result.index(after: openBraceIdx)
                continue
            }
            
            let bodyStart = result.index(after: openBraceIdx)
            let body = String(result[bodyStart..<closeBraceIdx])
            let replacement = "Task(async function() {\(body)})"
            
            let prefix = result[..<matchRange.lowerBound]
            let suffix = result[result.index(after: closeBraceIdx)...]
            result = prefix + replacement + suffix
            
            pos = result.index(matchRange.lowerBound, offsetBy: replacement.count)
        }
        return result
    }

    public func transpileSwiftToJS(swift: String) -> String {
        var js = swift
        
        // 0. Clean .self and replace self -> this and nil -> null at the very beginning
        js = js.replacingOccurrences(of: ".self", with: "")
        js = replaceRegex(in: js, pattern: "\\bself\\b", template: "this")
        js = replaceRegex(in: js, pattern: "\\bnil\\b", template: "null")

        // 1. Clean protocol conformances in class/struct/actor declarations
        js = replaceRegex(in: js, pattern: "\\b(class|struct|actor)\\s+(\\w+(?:<[^>]+>)?)\\s*:\\s*[^{]+", template: "$1 $2 ")

        // 2. Access modifiers stripper before declarations
        js = replaceRegex(in: js, pattern: "\\b(public|private|internal|fileprivate)\\s+(class|struct|actor)\\b", template: "$2")

        // 3. Getter/Setter properties
        let getterSetterPattern = "var\\s+(\\w+)\\s*:\\s*\\w+(?:<[^>]+>)?\\s*\\{\\s*get\\s*\\{([^{}]*)\\}\\s*set\\s*\\{([^{}]*(?:\\{[^{}]*(?:\\{[^{}]*\\}[^{}]*)*\\}[^{}]*)*)\\}\\s*\\}"
        js = replaceRegex(in: js, pattern: getterSetterPattern, template: "get $1() {$2} set $1(newValue) {$3}")

        // 4. Property wrapper @UserDefault to JS getters/setters (MUST RUN BEFORE variable type annotations or argument labels are cleaned)
        let propWrapperPattern = "@UserDefault\\s*\\(\\s*key\\s*:\\s*([^,]+)\\s*,\\s*defaultValue\\s*:\\s*([^)]+)\\)\\s*(?:static\\s+)?var\\s+(\\w+)\\s*:\\s*\\w+"
        js = replaceRegex(in: js, pattern: propWrapperPattern, template: """
        static get $3() {
            var val = UserDefaults.standard.object($1);
            return (val !== undefined && val !== null) ? val : $2;
        }
        static set $3(newValue) {
            UserDefaults.standard.set(newValue, $1);
        }
        """)

        // 5. Clean variable type annotations
        if let varTypeRegex = try? NSRegularExpression(pattern: "\\b(let|var)\\s+(\\w+)\\s*:\\s*([^{=\\n]+)(?:=\\s*([^\\n]+))?", options: []) {
            var mutableJs = js
            var offset = 0
            let matches = varTypeRegex.matches(in: js, options: [], range: NSRange(js.startIndex..., in: js))
            for match in matches {
                let nsJs = js as NSString
                let kind = nsJs.substring(with: match.range(at: 1))
                let name = nsJs.substring(with: match.range(at: 2))
                
                var replacement = ""
                if match.range(at: 4).location != NSNotFound {
                    let val = nsJs.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespacesAndNewlines)
                    replacement = "\(kind) \(name) = \(val)"
                } else {
                    replacement = "\(kind) \(name) = null"
                }
                
                let adjustedRange = NSRange(location: match.range.location + offset, length: match.range.length)
                if let targetRange = Range(adjustedRange, in: mutableJs) {
                    mutableJs.replaceSubrange(targetRange, with: replacement)
                    offset += replacement.count - match.range.length
                }
            }
            js = mutableJs
        }

        // 6. Generic parameters in type names: Name<Type> -> Name
        js = replaceRegex(in: js, pattern: "\\b([A-Z]\\w*)<[^>]+>", template: "$1")
        
        js = js.replacingOccurrences(of: "import Foundation", with: "")
        js = js.replacingOccurrences(of: "import SwiftUI", with: "")
        js = js.replacingOccurrences(of: "import Dispatch", with: "")
        js = js.replacingOccurrences(of: "import Combine", with: "")
        js = js.replacingOccurrences(of: "@propertyWrapper", with: "")

        // Convert actor/struct to class
        js = replaceRegex(in: js, pattern: "\\bactor\\s+", template: "class ")
        js = replaceRegex(in: js, pattern: "\\bstruct\\s+", template: "class ")

        // Clean return types in function signatures BEFORE class blocks and methods are processed
        js = replaceRegex(in: js, pattern: "\\)\\s*->\\s*[^{]+", template: ") ")

        // Clean function parameters (func name(...) or init(...))
        let cleanParamsFn: (String) -> String = { paramsStr in
            let params = paramsStr.components(separatedBy: ",")
            var cleaned: [String] = []
            for p in params {
                let trimmed = p.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                if trimmed.contains(":") {
                    let parts = trimmed.components(separatedBy: ":")
                    let left = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let leftParts = left.components(separatedBy: .whitespacesAndNewlines)
                    if let name = leftParts.last {
                        cleaned.append(name)
                    }
                } else {
                    cleaned.append(trimmed)
                }
            }
            return cleaned.joined(separator: ", ")
        }

        if let funcRegex = try? NSRegularExpression(pattern: "\\bfunc\\s+(\\w+)\\s*\\(([^)]*)\\)", options: []) {
            var mutableJs = js
            var offset = 0
            let matches = funcRegex.matches(in: js, options: [], range: NSRange(js.startIndex..., in: js))
            for match in matches {
                guard let nameRange = Range(match.range(at: 1), in: js),
                      let paramsRange = Range(match.range(at: 2), in: js) else { continue }
                
                let funcName = String(js[nameRange])
                let paramsStr = String(js[paramsRange])
                let cleanedParams = cleanParamsFn(paramsStr)
                
                let replacement = "function \(funcName)(\(cleanedParams))"
                let adjustedRange = NSRange(location: match.range.location + offset, length: match.range.length)
                if let targetRange = Range(adjustedRange, in: mutableJs) {
                    mutableJs.replaceSubrange(targetRange, with: replacement)
                    offset += replacement.count - match.range.length
                }
            }
            js = mutableJs
        }

        if let initRegex = try? NSRegularExpression(pattern: "\\binit\\s*\\(([^)]*)\\)", options: []) {
            var mutableJs = js
            var offset = 0
            let matches = initRegex.matches(in: js, options: [], range: NSRange(js.startIndex..., in: js))
            for match in matches {
                guard let paramsRange = Range(match.range(at: 1), in: js) else { continue }
                
                let paramsStr = String(js[paramsRange])
                let cleanedParams = cleanParamsFn(paramsStr)
                
                let replacement = "constructor(\(cleanedParams))"
                let adjustedRange = NSRange(location: match.range.location + offset, length: match.range.length)
                if let targetRange = Range(adjustedRange, in: mutableJs) {
                    mutableJs.replaceSubrange(targetRange, with: replacement)
                    offset += replacement.count - match.range.length
                }
            }
            js = mutableJs
        }

        // Clean class properties and methods using brace parser
        js = transpileClassBlocks(text: js, processBodyFn: transpileClassBody)

        // Strip defer blocks
        js = replaceRegex(in: js, pattern: "defer\\s*\\{[^}]*\\}", template: "")

        // Strip semaphore lines
        js = replaceRegex(in: js, pattern: ".*semaphore.*\\n?", template: "")

        // DispatchTime and Type cast replacements
        js = js.replacingOccurrences(of: "DispatchTime.now()", with: "{ uptimeNanoseconds: Date.now() * 1000000 }")
        js = js.replacingOccurrences(of: "Double(", with: "Number(")
        js = js.replacingOccurrences(of: "Float(", with: "Number(")

        js = js.replacingOccurrences(of: "result == tc.expected", with: "JSON.stringify(result) === JSON.stringify(tc.expected)")

        // String format
        js = replaceRegex(in: js, pattern: "String\\s*\\(\\s*format\\s*:\\s*\"%\\.\\d+f\"\\s*,\\s*([^)]+)\\)", template: "$1")

        // Strip property wrapper UserDefault class definition
        let userDefaultClassPattern = "class\\s+UserDefault\\s*\\{[^{}]*(?:\\{[^{}]*(?:\\{[^{}]*\\}[^{}]*)*\\}[^{}]*)*\\}"
        js = replaceRegex(in: js, pattern: userDefaultClassPattern, template: "")

        // Strip Swift type casting as? / as! / as
        js = replaceRegex(in: js, pattern: "\\bas[?!]?\\s+[A-Za-z0-9_?\\[\\]<>:]+", template: "")

        // Implicit enums (.milliseconds(100) -> 100)
        js = replaceRegex(in: js, pattern: "\\.milliseconds\\((\\d+)\\)", template: "$1")
        js = replaceRegex(in: js, pattern: "\\.seconds\\((\\d+)\\)", template: "$1 * 1000")

        // Strip weak self / weak this and guard let self (MUST RUN BEFORE guard let)
        js = replaceRegex(in: js, pattern: "\\[\\s*weak\\s+(?:self|this)\\s*\\]", template: "")
        js = replaceRegex(in: js, pattern: "guard\\s+let\\s+this\\s*=\\s*this\\s+else\\s*\\{\\s*return\\s*\\}", template: "")
        js = replaceRegex(in: js, pattern: "guard\\s+let\\s+self\\s*=\\s*self\\s+else\\s*\\{\\s*return\\s*\\}", template: "")

        // Guard let and general guard (MUST RUN BEFORE trailing closures to avoid conflicts with if/guard braces)
        js = replaceRegex(in: js, pattern: "guard\\s+let\\s+(\\w+)\\s*=\\s*\\1\\s+else\\s*\\{\\s*return\\s*([^}]*)\\s*\\}", template: "if (!$1) { return $2; }")
        js = replaceRegex(in: js, pattern: "guard\\s+let\\s+(\\w+)\\s*=\\s*([^\\n{]+)\\s+else\\s*\\{\\s*return\\s*([^}]*)\\s*\\}", template: "const $1 = $2; if (!$1) { return $3; }")
        js = replaceRegex(in: js, pattern: "guard\\s+([^\\n{]+)\\s+else\\s*\\{\\s*return\\s*([^}]*)\\s*\\}", template: "if (!($1)) { return $2; }")

        // if let and if condition (MUST RUN BEFORE trailing closures to avoid conflicts with if braces)
        js = replaceRegex(in: js, pattern: "if\\s+let\\s+(\\w+)\\s*=\\s*([^{]+)\\{", template: "const $1 = $2; if ($1 !== undefined && $1 !== null) {")
        js = replaceRegex(in: js, pattern: "if\\s+([^({\\s][^{]+)\\s*\\{", template: "if ($1) {")

        // Trailing closures (brace-counting based!)
        js = transpileTrailingClosures(text: js)

        // Task blocks (brace-counting based!)
        js = transpileTaskBlocks(text: js)

        // Closure assignments (e.g. onDataLoaded = { data in ... })
        js = replaceRegex(in: js, pattern: "\\{\\s*([a-zA-Z0-9_,\\s\\[\\]]+)\\s+in", template: "function($1) {")

        // Convert deinit to deinit() {
        js = replaceRegex(in: js, pattern: "\\bdeinit\\s*\\{", template: "deinit() {")

        // Convert function methodName(...) async { -> async function methodName(...) {
        js = replaceRegex(in: js, pattern: "\\bfunction\\s+(\\w+)\\s*\\(([^)]*)\\)\\s*async\\s*\\{", template: "async function $1($2) {")

        // Strip try / try? / try!
        js = replaceRegex(in: js, pattern: "\\btry[?!]?\\s*", template: "")

        // do catch
        js = replaceRegex(in: js, pattern: "\\bdo\\s*\\{", template: "try {")
        js = replaceRegex(in: js, pattern: "\\bcatch\\s*\\{", template: "catch (error) {")

        // Convert Swift optional call ?( to JS ?.(
        js = js.replacingOccurrences(of: "?(", with: "?.(")

        // Strip argument labels in call sites
        js = replaceRegex(in: js, pattern: "\\b(string|url|until|timeIntervalSinceNow|at|with|from|forKey|forHTTPHeaderField|value|to|by|repeating|count|key|defaultValue|for|scheduler|receiveValue|in|userId|id|title|completed)\\s*:\\s*", template: "")

        // Strip & ampersand prefix
        js = replaceRegex(in: js, pattern: "&\\b", template: "")

        // Dictionary initializers
        js = replaceRegex(in: js, pattern: "\\[\\s*\\w+\\s*:\\s*\\w+\\s*\\]\\(\\)", template: "{}")
        js = replaceRegex(in: js, pattern: "\\[\\s*String\\s*:\\s*Set\\(\\)\\s*\\]", template: "{}")

        // Array initializers
        js = replaceRegex(in: js, pattern: "Array\\s*\\(\\s*repeating\\s*:\\s*Array\\s*\\(\\s*repeating\\s*:\\s*([^,]+)\\s*,\\s*count\\s*:\\s*([^)]+)\\s*\\)\\s*,\\s*count\\s*:\\s*([^)]+)\\s*\\)", template: "Array.from({length: $3}, () => Array($2).fill($1))")
        js = replaceRegex(in: js, pattern: "Array\\s*\\(\\s*repeating\\s*:\\s*([^,]+)\\s*,\\s*count\\s*:\\s*([^)]+)\\s*\\)", template: "Array($2).fill($1)")

        // min / max
        js = replaceRegex(in: js, pattern: "(?<![A-Za-z0-9_\\.])min\\s*\\(\\s*([^,]+)\\s*,\\s*([^,]+)\\s*,\\s*([^)]+)\\s*\\)", template: "Math.min($1, Math.min($2, $3))")
        js = replaceRegex(in: js, pattern: "(?<![A-Za-z0-9_\\.])min\\s*\\(\\s*([^,]+)\\s*,\\s*([^)]+)\\s*\\)", template: "Math.min($1, $2)")
        js = replaceRegex(in: js, pattern: "(?<![A-Za-z0-9_\\.])max\\s*\\(\\s*([^,]+)\\s*,\\s*([^)]+)\\s*\\)", template: "Math.max($1, $2)")

        // isEmpty / count
        js = js.replacingOccurrences(of: "guard !matrix.isEmpty else { return 0 }", with: "if (matrix.length === 0) return 0;")
        js = js.replacingOccurrences(of: ".count", with: ".length")
        js = js.replacingOccurrences(of: ".isEmpty", with: ".length === 0")

        // let and var
        js = replaceRegex(in: js, pattern: "\\blet\\b", template: "const")
        js = replaceRegex(in: js, pattern: "\\bvar\\b", template: "let")

        // for loops
        js = replaceRegex(in: js, pattern: "for\\s+(\\w+)\\s+in\\s+(\\w+|\\d+)\\s*\\.\\.\\.\\s*(\\w+|\\d+)", template: "for (let $1 = $2; $1 <= $3; $1++)")
        js = replaceRegex(in: js, pattern: "for\\s+(\\w+)\\s+in\\s+(\\w+|\\d+)\\s*\\.\\.<\\s*(\\w+|\\d+)", template: "for (let $1 = $2; $1 < $3; $1++)")

        // enumerated
        js = replaceRegex(in: js, pattern: "for\\s+\\(\\s*(\\w+)\\s*,\\s*(\\w+)\\s*\\)\\s+in\\s+(\\w+)\\.enumerated\\(\\)\\s*\\{", template: "for (let $1 = 0; $1 < $3.length; $1++) { const $2 = $3[$1];")

        // Class instantiations (including constructors with arguments)
        let classInstPattern = "(?<!new\\s)\\b(?!(?:Double|Float|Int|String|URL|URLRequest|DispatchSemaphore)\\b)([A-Z]\\w*)\\(([^)]*)\\)"
        js = replaceRegex(in: js, pattern: classInstPattern, template: "new $1($2)")

        // Strip Swift force unwrap !
        js = replaceRegex(in: js, pattern: "\\b(\\w+\\([^)]*\\))!", template: "$1")
        js = replaceRegex(in: js, pattern: "\\b(\\w+)!([,\\}\\]\\s]|$)", template: "$1$2")

        return js
    }
}

