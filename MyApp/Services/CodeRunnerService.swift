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

        // NOTE: deliberately NOT overriding the global `Set` with a mock —
        // the real ES6 Set (natively available in JavaScriptCore) already
        // supports everything Swift's `Set` needs for this codebase's
        // solutions (`new Set(iterable)`, `.has()`, `.add()`), and does so
        // correctly. A previous mock class here only supported a no-arg
        // constructor and `.add`/`.push`, silently dropping any iterable
        // passed to `Set(someArray)` and having no `.has()` at all — every
        // solution constructing a Set from existing data (`Set(wordDict)`,
        // `Set<Character> = [...]`) was broken by this override.

        function isKnownUniquelyReferenced(x) { return false; }
        function abs(x) { return Math.abs(x); }

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
        var inString = false
        while idx < text.endIndex {
            let char = text[idx]
            if inString {
                // Skip string literal content — test-harness data routinely
                // contains literal `{`/`}` characters (e.g. bracket-matching
                // test cases like "{[]}"), which must not be counted as real
                // braces or this desyncs and misidentifies where a class/
                // closure body actually ends.
                if char == "\\" {
                    idx = text.index(idx, offsetBy: 1, limitedBy: text.endIndex) ?? text.endIndex
                    if idx < text.endIndex { idx = text.index(after: idx) }
                    continue
                }
                if char == "\"" { inString = false }
                idx = text.index(after: idx)
                continue
            }
            if char == "\"" {
                inString = true
            } else if char == "{" {
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
            let prefixCount = prefix.count
            let suffix = result[closeBraceIdx...]
            result = prefix + processedBody + suffix

            // Recompute the resume position from `result`'s OWN startIndex,
            // not by reusing `bodyStart` (an index captured against the
            // string value BEFORE this reassignment). `result = prefix +
            // processedBody + suffix` allocates a new String; reusing an
            // index from the prior value on the new one is undefined
            // behavior in Swift — it often happens to still land in the
            // right place for plain ASCII content, which is exactly what
            // made this look safe across many earlier questions, but it
            // silently produced an off-by-a-few-characters position (landing
            // mid-identifier, e.g. "intervals" truncated to "tervals") for
            // at least one solution once the preceding processedBody length
            // changed. Counting in characters from `result.startIndex` is
            // correct regardless of the string's underlying storage.
            let newCloseBraceIdx = result.index(result.startIndex, offsetBy: prefixCount + processedBody.count)
            pos = result.index(after: newCloseBraceIdx)
        }
        return result
    }

    private func findMatchingParen(chars: [Character], openIdx: Int) -> Int? {
        var depth = 0
        var i = openIdx
        var inString = false
        while i < chars.count {
            let c = chars[i]
            if inString {
                // Skip string literal content — a `(` or `)` inside test data
                // (e.g. `TestCase(s: "(]", ...)`) is not a real paren and
                // must not affect the depth count, or the scan desyncs and
                // either returns the wrong close index or none at all.
                if c == "\\", i + 1 < chars.count { i += 2; continue }
                if c == "\"" { inString = false }
                i += 1
                continue
            }
            if c == "\"" {
                inString = true
            } else if c == "(" {
                depth += 1
            } else if c == ")" {
                depth -= 1
                if depth == 0 { return i }
            }
            i += 1
        }
        return nil
    }

    /// Splits a call's argument text on top-level commas (i.e. not inside
    /// nested `()`/`[]`/`{}` or a string literal), then strips a leading
    /// Swift argument label (`identifier:`) from each piece if present.
    /// Needed because call-site labels can be arbitrary field names (every
    /// test-harness helper struct has its own), so a fixed whitelist of
    /// known label names can never cover them all.
    /// Splits `text` on top-level commas — i.e. not inside nested
    /// `()`/`[]`/`{}` or a string literal. Shared by `stripCallSiteLabels`
    /// (splitting call arguments) and `transpileGuardMultiCondition`
    /// (splitting a guard's comma-separated conditions).
    private func splitTopLevelCommas(_ text: String) -> [String] {
        let chars = Array(text)
        var pieces: [String] = []
        var current: [Character] = []
        var depth = 0
        var inString = false
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inString {
                current.append(c)
                if c == "\\", i + 1 < chars.count {
                    current.append(chars[i + 1])
                    i += 2
                    continue
                }
                if c == "\"" { inString = false }
                i += 1
                continue
            }
            switch c {
            case "\"":
                inString = true
                current.append(c)
            case "(", "[", "{":
                depth += 1
                current.append(c)
            case ")", "]", "}":
                depth -= 1
                current.append(c)
            case ",":
                if depth == 0 {
                    pieces.append(String(current))
                    current = []
                } else {
                    current.append(c)
                }
            default:
                current.append(c)
            }
            i += 1
        }
        if !String(current).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pieces.append(String(current))
        }
        return pieces
    }

    /// Rewrites `guard condA, condB, ... else { ... }` into `guard condA &&
    /// condB && ... else { ... }` so the existing guard-specific regexes
    /// (which only handle a single condition) see one flattened expression.
    private func transpileGuardMultiCondition(text: String) -> String {
        guard let guardRegex = try? NSRegularExpression(pattern: "guard\\s+([^\\n{]+?)\\s+else\\s*\\{", options: []) else {
            return text
        }
        let ns = text as NSString
        let matches = guardRegex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        var mutableText = text
        var offset = 0
        for match in matches {
            let condRange = match.range(at: 1)
            let cond = ns.substring(with: condRange)
            let pieces = splitTopLevelCommas(cond).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard pieces.count > 1 else { continue }
            // Skip a `guard let x = expr, cond2 else` mix — a `let` binding
            // isn't a boolean and can't be `&&`-joined with one; that shape
            // needs different handling this pass doesn't attempt, and
            // flattening it here would silently produce nonsense.
            guard !pieces.contains(where: { $0.range(of: "^let\\s+", options: .regularExpression) != nil }) else { continue }
            let flattened = pieces.joined(separator: " && ")
            let adjustedRange = NSRange(location: condRange.location + offset, length: condRange.length)
            if let targetRange = Range(adjustedRange, in: mutableText) {
                mutableText.replaceSubrange(targetRange, with: flattened)
                offset += flattened.count - condRange.length
            }
        }
        return mutableText
    }

    private func stripCallSiteLabels(_ argsText: String) -> String {
        let pieces = splitTopLevelCommas(argsText)

        let labelRegex = try? NSRegularExpression(pattern: "^\\s*[A-Za-z_]\\w*\\s*:\\s*(?!:)", options: [])
        let cleaned = pieces.map { rawPiece -> String in
            // Recurse into each argument BEFORE label-stripping: an argument
            // can itself be (or contain, e.g. inside a trailing-closure
            // argument's body) other constructor/method calls that also need
            // "new " added and their own labels stripped — e.g. a test
            // harness's `TestCase("...", function() { let x =
            // SomeOtherType(a: 1) }) `. Without this, findMatchingParen
            // already correctly finds the true end of a multi-line argument
            // list like that (it's paren-balanced), but everything inside it
            // was previously treated as opaque text and passed through
            // unconverted, since the outer scan jumps straight past the
            // whole thing once it has this argument list in hand.
            let piece = transpileClassInstantiations(text: rawPiece)
            let ns = piece as NSString
            if let labelRegex,
               let m = labelRegex.firstMatch(in: piece, options: [], range: NSRange(location: 0, length: ns.length)) {
                return ns.substring(from: m.range.length).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return piece.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned.joined(separator: ", ")
    }

    /// Replaces the old single-line regex `(?<!new\s)\b(?!excluded)([A-Z]\w*)\(([^)]*)\)`
    /// -> `new $1($2)`, which had two compounding bugs: `[^)]*` truncates at
    /// the FIRST `)`, mangling any call whose arguments contain a nested call
    /// (e.g. `TestCase(nums: Array(repeating: 0, count: 3), ...)`), and it
    /// never stripped Swift argument labels from those arguments at all —
    /// only a separate, unrelated whitelist-based pass a few steps later
    /// stripped a fixed set of previously-seen label names, which silently
    /// leaves invalid `label: value` syntax in `new X(...)` calls for any
    /// custom struct with its own field names (i.e. virtually every
    /// test-harness helper struct, since each one names its fields
    /// differently).
    ///
    /// Also handles lowercase call sites (`limiter.allowRequest(currentTime:
    /// 0)`, plain function calls) the same way: the whitelist-based label
    /// stripper a few steps earlier only knows a fixed set of label names
    /// ever seen before (`url`, `forKey`, etc.) and silently leaves any other
    /// label (e.g. a parameter named `currentTime`, `cost`, ...) untouched.
    /// Excludes common control-flow keywords, which by this point in the
    /// pipeline are already followed by real parens (`if (cond) {`, `for
    /// (...)`, etc.) and must not be treated as callables.
    private func transpileClassInstantiations(text: String) -> String {
        // "Array" is excluded here deliberately: bare `Array(someString)` is
        // Swift's idiom for "split this string/iterable into an array of its
        // elements" and must become `Array.from(x)`, not `new Array(x)` —
        // the latter is a totally different JS operation (creates a
        // single-element array `[x]`, or if x happens to be a number, an
        // EMPTY array of that length). The `Array(repeating:count:)` /
        // `[Type](repeating:count:)` initializer forms are converted to
        // their own explicit `new Array(n).fill(v)` by dedicated regexes
        // above this pass, so "Array" never needs the generic auto-`new`
        // here at all — see the `Array.from` conversion below.
        let excludedFromNew: Set<String> = ["Double", "Float", "Int", "String", "URL", "URLRequest", "DispatchSemaphore", "Number", "Array"]
        let excludedKeywords: Set<String> = ["if", "while", "for", "switch", "catch", "return", "function", "else", "do", "try", "throw", "typeof", "instanceof", "new", "in", "of", "await", "async", "break", "continue", "case", "default", "constructor"]
        let chars = Array(text)
        var result = ""
        var i = 0
        while i < chars.count {
            let c = chars[i]
            let atWordStart = (i == 0) || !(chars[i - 1].isLetter || chars[i - 1].isNumber || chars[i - 1] == "_")
            if (c.isLetter || c == "_"), atWordStart {
                var j = i
                while j < chars.count, (chars[j].isLetter || chars[j].isNumber || chars[j] == "_") {
                    j += 1
                }
                let name = String(chars[i..<j])
                if j < chars.count, chars[j] == "(", !excludedKeywords.contains(name) {
                    let isTypeName = name.first?.isUppercase == true
                    let trimmedResult = result.trimmingCharacters(in: .whitespaces)
                    let alreadyNew = trimmedResult.hasSuffix("new")
                    guard let closeIdx = findMatchingParen(chars: chars, openIdx: j) else {
                        result += name
                        i = j
                        continue
                    }
                    let argsText = String(chars[(j + 1)..<closeIdx])
                    let cleanedArgs = stripCallSiteLabels(argsText)
                    let prefix = (isTypeName && !excludedFromNew.contains(name) && !alreadyNew) ? "new " : ""
                    result += prefix + name + "(" + cleanedArgs + ")"
                    i = closeIdx + 1
                    continue
                }
                result += name
                i = j
                continue
            }
            result.append(c)
            i += 1
        }
        return result
    }

    private func findMatchingBracket(chars: [Character], openIdx: Int) -> Int? {
        var depth = 0
        var i = openIdx
        var inString = false
        while i < chars.count {
            let c = chars[i]
            if inString {
                if c == "\\", i + 1 < chars.count { i += 2; continue }
                if c == "\"" { inString = false }
                i += 1
                continue
            }
            if c == "\"" { inString = true }
            else if c == "[" { depth += 1 }
            else if c == "]" {
                depth -= 1
                if depth == 0 { return i }
            }
            i += 1
        }
        return nil
    }

    private func hasTopLevelColon(_ text: String) -> Bool {
        let chars = Array(text)
        var depth = 0
        var inString = false
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inString {
                if c == "\\", i + 1 < chars.count { i += 2; continue }
                if c == "\"" { inString = false }
                i += 1
                continue
            }
            switch c {
            case "\"": inString = true
            case "(", "[", "{": depth += 1
            case ")", "]", "}": depth -= 1
            case ":":
                if depth == 0 { return true }
            default: break
            }
            i += 1
        }
        return false
    }

    /// Converts Swift dictionary literals (`[key1: val1, key2: val2]`) into JS
    /// object literals (`{key1: val1, key2: val2}`). Distinguishes a dict
    /// literal from a plain array literal / subscript by scanning for a
    /// top-level colon inside the brackets (ignoring colons nested inside
    /// further brackets, parens, or string content). Recurses into non-dict
    /// brackets (plain arrays, subscripts like `arr[i]`) in case they contain
    /// a nested dict literal, leaving them otherwise untouched.
    private func transpileDictionaryLiterals(text: String) -> String {
        let chars = Array(text)
        var result = ""
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "[" {
                guard let closeIdx = findMatchingBracket(chars: chars, openIdx: i) else {
                    result.append(c)
                    i += 1
                    continue
                }
                let inner = String(chars[(i + 1)..<closeIdx])
                if hasTopLevelColon(inner) {
                    result += "{" + transpileDictionaryLiterals(text: inner) + "}"
                } else {
                    result += "[" + transpileDictionaryLiterals(text: inner) + "]"
                }
                i = closeIdx + 1
                continue
            }
            result.append(c)
            i += 1
        }
        return result
    }

    /// Scans `text` (the methods portion of a class body) for each
    /// `function name(...) { ... }` / `constructor(...) { ... }` unit, skips
    /// its parameter list untouched, and within its `{...}` body only,
    /// prepends `this.` to any bare occurrence of a name in `memberNames`
    /// that isn't already member-accessed (preceded by `this.` or any other
    /// `.`) AND isn't one of THIS method's own parameter names — a
    /// parameter is routinely named identically to the property it
    /// initializes (e.g. `constructor(capacity) { this.capacity =
    /// capacity }`, from Swift's equally common `init(_ capacity: Int) {
    /// self.capacity = capacity }`), and blanket-prefixing every occurrence
    /// would corrupt the bare parameter reference on the right-hand side
    /// into `this.capacity` too. Text outside any recognized method body
    /// (whitespace between methods) passes through unchanged.
    /// Scans `text` (the methods portion of a class body) for each
    /// TOP-LEVEL `function name(...) { ... }` / `constructor(...) { ... }`
    /// unit and collects just the names, skipping over each one's entire
    /// body (via brace-matching) without descending into it — so a Swift
    /// local function nested inside another method is never mistaken for a
    /// sibling class method.
    private func topLevelMethodNames(in text: String) -> Set<String> {
        guard let declRegex = try? NSRegularExpression(pattern: "\\b(?:function\\s+(\\w+)|(constructor))\\s*\\(", options: []) else {
            return []
        }
        let chars = Array(text)
        var names: Set<String> = []
        var searchStart = 0
        while searchStart < chars.count {
            let remaining = String(chars[searchStart...])
            let nsRemaining = remaining as NSString
            guard let match = declRegex.firstMatch(in: remaining, options: [], range: NSRange(location: 0, length: nsRemaining.length)) else {
                break
            }
            if match.range(at: 1).location != NSNotFound {
                names.insert(nsRemaining.substring(with: match.range(at: 1)))
            }
            let matchEndInRemaining = match.range.location + match.range.length
            let declEndIdx = searchStart + matchEndInRemaining
            let openParenIdx = declEndIdx - 1
            guard let closeParenIdx = findMatchingParen(chars: chars, openIdx: openParenIdx) else {
                searchStart = declEndIdx
                continue
            }
            var afterParen = closeParenIdx + 1
            while afterParen < chars.count, chars[afterParen] != "{" {
                afterParen += 1
            }
            guard afterParen < chars.count else {
                searchStart = afterParen
                continue
            }
            guard let closeBraceIdx = findMatchingBrace(text: text, startIndex: text.index(text.startIndex, offsetBy: afterParen)) else {
                break
            }
            searchStart = text.distance(from: text.startIndex, to: closeBraceIdx) + 1
        }
        return names
    }

    private func addThisPrefixWithinMethodBodies(_ text: String, memberNames: Set<String>) -> String {
        func applyToBody(_ body: String, excluding paramNames: Set<String>) -> String {
            let effectiveNames = memberNames.subtracting(paramNames)
            guard !effectiveNames.isEmpty else { return body }
            let escapedNames = effectiveNames.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
            guard let memberPattern = try? NSRegularExpression(pattern: "(?<!this\\.)(?<!\\.)\\b(\(escapedNames))\\b", options: []) else {
                return body
            }
            let ns = body as NSString
            let range = NSRange(location: 0, length: ns.length)
            return memberPattern.stringByReplacingMatches(in: body, options: [], range: range, withTemplate: "this.$1")
        }
        func paramNames(from paramsText: String) -> Set<String> {
            let names = paramsText.components(separatedBy: ",").compactMap { piece -> String? in
                let name = piece.components(separatedBy: "=").first?.trimmingCharacters(in: .whitespacesAndNewlines)
                return (name?.isEmpty ?? true) ? nil : name
            }
            return Set(names)
        }

        guard let declRegex = try? NSRegularExpression(pattern: "\\b(?:function\\s+\\w+|constructor)\\s*\\(", options: []) else {
            return text
        }
        let chars = Array(text)
        var result = ""
        var searchStart = 0
        while searchStart < chars.count {
            let remaining = String(chars[searchStart...])
            guard let match = declRegex.firstMatch(in: remaining, options: [], range: NSRange(location: 0, length: (remaining as NSString).length)) else {
                result += remaining
                break
            }
            let matchEndInRemaining = match.range.location + match.range.length
            let declEndIdx = searchStart + matchEndInRemaining
            // matchEndInRemaining points just past the opening `(` of the parameter list
            let openParenIdx = declEndIdx - 1
            result += String(chars[searchStart..<declEndIdx])
            guard let closeParenIdx = findMatchingParen(chars: chars, openIdx: openParenIdx) else {
                searchStart = declEndIdx
                continue
            }
            let paramsText = String(chars[(openParenIdx + 1)..<closeParenIdx])
            let thisMethodParams = paramNames(from: paramsText)
            result += paramsText + ")"
            var afterParen = closeParenIdx + 1
            while afterParen < chars.count, chars[afterParen] != "{" {
                result.append(chars[afterParen])
                afterParen += 1
            }
            guard afterParen < chars.count else {
                searchStart = afterParen
                continue
            }
            let bodyText = String(text[text.index(text.startIndex, offsetBy: afterParen)...])
            guard let closeBraceIdx = findMatchingBrace(text: text, startIndex: text.index(text.startIndex, offsetBy: afterParen)) else {
                result += bodyText
                break
            }
            let closeBraceOffset = text.distance(from: text.startIndex, to: closeBraceIdx)
            let body = String(chars[(afterParen + 1)..<closeBraceOffset])
            result += "{" + applyToBody(body, excluding: thisMethodParams) + "}"
            searchStart = closeBraceOffset + 1
        }
        return result
    }

    private func transpileClassBody(body: String) -> String {
        // NOTE: transpileClassBlocks (called from transpileSwiftToJS) runs this
        // AFTER `func` -> `function` and `init` -> `constructor` have already
        // been rewritten (see the funcRegex/initRegex passes earlier in
        // transpileSwiftToJS). Matching the literal `\binit\b`/`\bfunc\b` here
        // is a no-op by this point (`\bfunc\b` can never match inside
        // `function`), which silently made this separator fail to find any
        // boundary for the extremely common case of a class with exactly one
        // method and no properties — e.g. `class Solution { func x() {...} }`
        // — causing the entire method body to be misclassified as "stored
        // properties" and have every `let`/`var` stripped outright. Search for
        // the POST-rename tokens instead so the boundary is actually found.
        let separatorPattern = "(\\bconstructor\\b|\\bfunction\\b|\\bdeinit\\b|\\bget\\b|\\bset\\b)"
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

        // Prepend `this.` to bare references to this class's own properties
        // and methods inside method bodies. Swift lets a method omit `self.`
        // entirely when calling its own methods or reading/writing its own
        // properties; JS has no such implicit lookup, so `tokens >= cost` or
        // `refill(t)` inside a method silently reference undefined globals
        // instead of `this.tokens`/`this.refill(t)`. This used to be a
        // hardcoded 4-name whitelist (`box`, `cache`, `searchPublisher`,
        // `cancellables`) left over from whichever specific question needed
        // it first — anything outside that exact list (which is most
        // properties, on most classes) was silently left broken. Extracts
        // the real property/method names for THIS class and substitutes
        // generally, but only inside method BODIES (via brace-matching),
        // never inside a parameter list — otherwise a parameter that happens
        // to share a property's name (e.g. `constructor(capacity)` assigning
        // `this.capacity`) would corrupt into `constructor(this.capacity)`,
        // which JS doesn't allow as a parameter name.
        let nsCleanPropsForNames = cleanedProperties as NSString
        var memberNames: Set<String> = []
        if let propNameRegex = try? NSRegularExpression(pattern: "\\b(\\w+)\\s*=", options: []) {
            let nameMatches = propNameRegex.matches(in: cleanedProperties, options: [], range: NSRange(location: 0, length: nsCleanPropsForNames.length))
            memberNames.formUnion(nameMatches.map { nsCleanPropsForNames.substring(with: $0.range(at: 1)) })
        }
        // Only TOP-LEVEL method names count as class members here — a plain
        // regex search for `function NAME(` would also match a Swift local
        // function nested inside another method's body (e.g. `func sink(...)
        // {...}` declared inside `numIslands`), incorrectly treating it as a
        // sibling method of the class and prepending `this.` to its every
        // use, including its own declaration (`function this.sink(...)`,
        // invalid JS) and its recursive calls (which need to stay bare —
        // Swift local functions are ordinary closures, not `self`-bound
        // members, and were never callable via `self.sink(...)` either).
        memberNames.formUnion(topLevelMethodNames(in: rest))
        if !memberNames.isEmpty {
            rest = addThisPrefixWithinMethodBodies(rest, memberNames: memberNames)
        }

        var combined = cleanedProperties + rest

        // No explicit constructor/method was found (`match == nil`): this is
        // a plain data struct/class relying on Swift's implicit memberwise
        // initializer, e.g. `struct TestCase { let nums: [Int]; let target: Int }`
        // — the shape of virtually every test-harness helper struct in this
        // app. The transpiler otherwise has no representation for that
        // implicit initializer at all, so `TestCase(nums: ..., target: ...)`
        // call sites (rewritten elsewhere to positional `new TestCase(...)`)
        // would construct a class with no constructor to bind their
        // positional arguments to. Synthesize one explicitly, in property
        // declaration order — which Swift's own call-site argument order is
        // guaranteed to match for a memberwise initializer.
        if match == nil {
            let nsCleanProps = cleanedProperties as NSString
            if let propNameRegex = try? NSRegularExpression(pattern: "\\b(\\w+)\\s*=", options: []) {
                let nameMatches = propNameRegex.matches(in: cleanedProperties, options: [], range: NSRange(location: 0, length: nsCleanProps.length))
                let names = nameMatches.map { nsCleanProps.substring(with: $0.range(at: 1)) }
                if !names.isEmpty {
                    let params = names.joined(separator: ", ")
                    let assignments = names.map { "this.\($0) = \($0);" }.joined(separator: " ")
                    combined += "\nconstructor(\(params)) { \(assignments) }\n"
                }
            }
        }
        
        // Convert function methodName(...) { -> methodName(...) { — JS class
        // method syntax omits `function`, unlike a standalone JS function
        // statement. Must only strip it from TOP-LEVEL method declarations,
        // not from a Swift local function nested inside another method's
        // body (e.g. `func sink(...) {...}` declared inside `numIslands`) —
        // that one is a real standalone JS function statement once inside a
        // method body, and DOES need to keep the `function` keyword, or the
        // parser sees a bare `name(...) {` and treats it as an (invalid,
        // since we're not inside a class body at that point) method shorthand.
        return stripFunctionKeywordAtTopLevel(combined)
    }

    /// Scans `text` for TOP-LEVEL `function name(...) {` declarations and
    /// strips the `function` keyword from just those, skipping over each
    /// one's own body (via brace-matching) so a nested/local function
    /// declared inside that body is left untouched.
    private func stripFunctionKeywordAtTopLevel(_ text: String) -> String {
        guard let declRegex = try? NSRegularExpression(pattern: "\\bfunction\\s+(\\w+)\\s*\\(", options: []) else {
            return text
        }
        let chars = Array(text)
        var result = ""
        var searchStart = 0
        while searchStart < chars.count {
            let remaining = String(chars[searchStart...])
            let nsRemaining = remaining as NSString
            guard let match = declRegex.firstMatch(in: remaining, options: [], range: NSRange(location: 0, length: nsRemaining.length)) else {
                result += remaining
                break
            }
            let matchStartInRemaining = match.range.location
            let matchEndInRemaining = match.range.location + match.range.length
            let name = nsRemaining.substring(with: match.range(at: 1))
            // Copy everything before this match unchanged, then emit the
            // stripped declaration (`name(` instead of `function name(`).
            result += String(chars[searchStart..<(searchStart + matchStartInRemaining)])
            result += "\(name)("
            let openParenIdx = searchStart + matchEndInRemaining - 1
            guard let closeParenIdx = findMatchingParen(chars: chars, openIdx: openParenIdx) else {
                searchStart = searchStart + matchEndInRemaining
                continue
            }
            result += String(chars[(openParenIdx + 1)..<closeParenIdx]) + ")"
            var afterParen = closeParenIdx + 1
            while afterParen < chars.count, chars[afterParen] != "{" {
                result.append(chars[afterParen])
                afterParen += 1
            }
            guard afterParen < chars.count else {
                searchStart = afterParen
                continue
            }
            guard let closeBraceIdx = findMatchingBrace(text: text, startIndex: text.index(text.startIndex, offsetBy: afterParen)) else {
                result += String(text[text.index(text.startIndex, offsetBy: afterParen)...])
                break
            }
            let closeBraceOffset = text.distance(from: text.startIndex, to: closeBraceIdx)
            // The body (between the braces) is copied through UNCHANGED —
            // any nested `function` declarations inside it keep their keyword.
            result += "{" + String(chars[(afterParen + 1)..<closeBraceOffset]) + "}"
            searchStart = closeBraceOffset + 1
        }
        return result
    }

    /// Scans a closure body with no explicit `in` clause for Swift's
    /// shorthand argument names (`$0`, `$1`, ...) and returns a comma-joined
    /// JS parameter list covering every index used (e.g. `$0, $1` if both
    /// appear, even if only `$1` is referenced — Swift requires them used in
    /// order starting from `$0`). Returns an empty string if none are used.
    /// Swift closures whose body is a single expression (no explicit
    /// `return`) implicitly return that expression's value — required for
    /// comparator/predicate closures like `.sorted { $0[0] < $1[0] }` or
    /// `.first { $0.isValid }` to actually produce a result. JS has no such
    /// implicit-return rule for `function(...) {...}` bodies, so those
    /// closures silently always returned `undefined` before this. Only
    /// wraps genuinely single-expression bodies (no explicit `return`, no
    /// statement-separating semicolons, no multi-line block structure) —
    /// leaves ordinary multi-statement closures untouched.
    ///
    /// `forSortComparator` handles a separate, distinct problem specific to
    /// `.sorted { ... }`/`.sort { ... }`: Swift's sort closure signature is
    /// `(Element, Element) -> Bool` ("is the first argument ordered before
    /// the second"), but JS's `Array.prototype.sort` comparator signature is
    /// `(a, b) -> Number` (negative/zero/positive). Passing the boolean
    /// straight through gets coerced to `1`/`0`, which is not a valid
    /// comparator — `0` collapses "equal" and "a is after b" into the same
    /// signal, so the sort silently produces a wrong, inconsistent order
    /// (confirmed empirically: `.sorted { $0[0] < $1[0] }` on 4 intervals
    /// collapsed a 3-element merged result down to 1 element). The standard
    /// fix for boolean-predicate-to-comparator is `predicate(a,b) ? -1 : 1`
    /// — never `0` — which is internally consistent for any valid strict
    /// weak ordering (the same predicate used from either argument order
    /// consistently agrees on the relative order).
    private func wrapImplicitReturnIfNeeded(_ body: String, forSortComparator: Bool = false) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return body }
        guard !trimmed.hasPrefix("return") else { return body }
        let controlFlowPrefixes = ["if", "guard", "for", "while", "switch", "do", "let ", "var ", "const ", "function"]
        guard !controlFlowPrefixes.contains(where: { trimmed.hasPrefix($0) }) else { return body }
        guard !trimmed.contains(";"), !trimmed.contains("\n") else { return body }
        if forSortComparator {
            return " return (\(trimmed)) ? -1 : 1; "
        }
        return " return \(trimmed); "
    }

    private func shorthandClosureParams(_ body: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\$(\\d+)", options: []) else { return "" }
        let ns = body as NSString
        let matches = regex.matches(in: body, options: [], range: NSRange(location: 0, length: ns.length))
        guard let maxIndex = matches.compactMap({ Int(ns.substring(with: $0.range(at: 1))) }).max() else { return "" }
        return (0...maxIndex).map { "$\($0)" }.joined(separator: ", ")
    }

    private func transpileTrailingClosures(text: String) -> String {
        var result = text

        // 0. Match BareUppercaseType(args) { body } — a struct/type
        // constructor call with a Swift trailing closure, e.g.
        // `TestCase("name") { ... assertion body ... }` (used throughout
        // this codebase's own test harnesses for helper structs with a
        // closure-typed field). Restricted to an uppercase-starting name
        // specifically so this can never collide with `if (...)  {`, `while
        // (...) {`, etc., which are always lowercase — unlike pattern 1
        // below this needs no dot prefix to disambiguate from those
        // keywords, since none of them start with a capital letter.
        let pattern0 = "(?<![\\w.])([A-Z]\\w*)\\s*\\(([^)]*)\\)\\s*\\{"
        if let regex0 = try? NSRegularExpression(pattern: pattern0, options: []) {
            var pos0 = result.startIndex
            while pos0 < result.endIndex {
                let remainingRange = NSRange(pos0..., in: result)
                guard let match = regex0.firstMatch(in: result, options: [], range: remainingRange),
                      let matchRange = Range(match.range, in: result) else {
                    break
                }

                let nsResult = result as NSString
                let typeName = nsResult.substring(with: match.range(at: 1))
                let args = nsResult.substring(with: match.range(at: 2))

                if args.contains("function") {
                    pos0 = result.index(matchRange.lowerBound, offsetBy: match.range.length)
                    continue
                }

                guard let openBraceIdx = result[matchRange.lowerBound...].firstIndex(of: "{") else {
                    pos0 = result.index(matchRange.lowerBound, offsetBy: match.range.length)
                    continue
                }

                guard let closeBraceIdx = findMatchingBrace(text: result, startIndex: openBraceIdx) else {
                    pos0 = result.index(after: openBraceIdx)
                    continue
                }

                let bodyStart = result.index(after: openBraceIdx)
                let body = String(result[bodyStart..<closeBraceIdx])
                let argsPrefix = args.isEmpty ? "" : "\(args), "
                let replacement = "\(typeName)(\(argsPrefix)function() {\(body)})"

                let prefix = result[..<matchRange.lowerBound]
                let suffix = result[result.index(after: closeBraceIdx)...]
                result = prefix + replacement + suffix

                pos0 = result.index(matchRange.lowerBound, offsetBy: replacement.count)
            }
        }

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
            let inPattern = "^\\s*([a-zA-Z0-9_\\s\\[\\]]+)\\s+in\\b"
            if let inRegex = try? NSRegularExpression(pattern: inPattern, options: []),
               let inMatch = inRegex.firstMatch(in: body, options: [], range: NSRange(location: 0, length: (body as NSString).length)) {
                var params = (body as NSString).substring(with: inMatch.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                params = replaceRegex(in: params, pattern: "\\[[^\\]]+\\]", template: "").trimmingCharacters(in: .whitespacesAndNewlines)
                let closureBody = String(body.suffix(from: body.index(body.startIndex, offsetBy: inMatch.range.length)))
                replacement = ".\(methodName)(\(args), function(\(params)) {\(closureBody)})"
            } else {
                // No explicit `in` clause — check for Swift's shorthand
                // closure argument names (`$0`, `$1`, ...), e.g. `.sorted {
                // $0[0] < $1[0] }`. `$0`/`$1` are valid JS identifiers too,
                // so simply declaring them as real parameters makes the
                // closure body work unmodified; previously this fell
                // through to a zero-parameter `function() {...}`, leaving
                // `$0`/`$1` as unbound identifiers (a ReferenceError at
                // runtime, or worse, silently reading a stale outer-scope
                // global of the same name).
                let params = shorthandClosureParams(body)
                let wrappedBody = wrapImplicitReturnIfNeeded(body, forSortComparator: methodName == "sorted" || methodName == "sort")
                replacement = ".\(methodName)(\(args), function(\(params)) {\(wrappedBody)})"
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
            let inPattern = "^\\s*([a-zA-Z0-9_\\s\\[\\]]+)\\s+in\\b"
            if let inRegex = try? NSRegularExpression(pattern: inPattern, options: []),
               let inMatch = inRegex.firstMatch(in: body, options: [], range: NSRange(location: 0, length: (body as NSString).length)) {
                var params = (body as NSString).substring(with: inMatch.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                params = replaceRegex(in: params, pattern: "\\[[^\\]]+\\]", template: "").trimmingCharacters(in: .whitespacesAndNewlines)
                let closureBody = String(body.suffix(from: body.index(body.startIndex, offsetBy: inMatch.range.length)))
                replacement = ".\(methodName)(function(\(params)) {\(closureBody)})"
            } else {
                let shorthandParams = shorthandClosureParams(body)
                let wrappedBody = wrapImplicitReturnIfNeeded(body, forSortComparator: methodName == "sorted" || methodName == "sort")
                replacement = ".\(methodName)(function(\(shorthandParams)) {\(wrappedBody)})"
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

    /// Converts Swift string interpolation (`"...\(expr)..."`) into JS
    /// template literals (`` `...${expr}...` ``). This was previously handled
    /// nowhere in the pipeline except one narrow `DispatchTime.now()` special
    /// case — every other `print("... \(x) ...")` in a testHarness (which is
    /// effectively all of them, since that's the sentinel output format every
    /// question relies on) was left as literal, invalid `\(...)` inside a
    /// plain JS string, throwing a SyntaxError. Uses manual paren-balance
    /// scanning rather than a regex, since interpolated expressions routinely
    /// contain their own nested parens (e.g. `\(String(format: "%.3f", x))`)
    /// that a non-greedy `[^)]*` regex would truncate at the first `)`.
    /// Recursively extracts every `class`/`struct`/`actor` declaration
    /// nested directly inside another type's body, moving each one to a
    /// top-level sibling declaration immediately BEFORE the type that used
    /// to contain it (so it's fully defined before that type's own methods
    /// reference it). Operates on plain Swift source text, before any other
    /// transpilation — brace-matching alone is enough since braces mean the
    /// same thing in both languages at this stage.
    private func hoistNestedTypeDeclarations(_ text: String) -> String {
        guard let declRegex = try? NSRegularExpression(pattern: "\\b(?:private\\s+|public\\s+|internal\\s+|fileprivate\\s+)?(class|struct|actor)\\s+(\\w+)", options: []) else {
            return text
        }

        // Walks `slice` left to right, leaving its OWN top-level sequence of
        // declarations/text in original order (this must NOT reorder
        // anything at this level — e.g. `class Solution {...}` followed by
        // `let solution = Solution()` followed by `class TestCase {...}`
        // must stay in exactly that order). For each type declaration found,
        // its body is handed to `extractNested`, which pulls any type
        // declarations nested directly inside THAT body out and returns them
        // separately — those get spliced in immediately before this
        // declaration (still at the same position in the overall sequence),
        // while everything else keeps flowing through untouched.
        func processSequentially(_ slice: [Character]) -> String {
            var result = ""
            var searchStart = 0
            while searchStart < slice.count {
                let remaining = String(slice[searchStart...])
                let nsRemaining = remaining as NSString
                guard let match = declRegex.firstMatch(in: remaining, options: [], range: NSRange(location: 0, length: nsRemaining.length)) else {
                    result += remaining
                    break
                }
                let matchStartInRemaining = match.range.location
                let matchEndInRemaining = match.range.location + match.range.length
                result += String(remaining.prefix(matchStartInRemaining))

                let declTextChars = Array(slice[(searchStart + matchStartInRemaining)..<(searchStart + matchEndInRemaining)])
                let searchFromOpenBrace = searchStart + matchEndInRemaining
                guard let openBraceOffset = slice[searchFromOpenBrace...].firstIndex(of: "{") else {
                    result += String(slice[(searchStart + matchStartInRemaining)...])
                    break
                }
                guard let closeBraceOffset = findMatchingBraceInChars(slice, openIdx: openBraceOffset) else {
                    result += String(slice[(searchStart + matchStartInRemaining)...])
                    break
                }

                let declHeader = String(declTextChars) + String(slice[searchFromOpenBrace..<(openBraceOffset + 1)])
                let body = Array(slice[(openBraceOffset + 1)..<closeBraceOffset])
                let (hoistedFromBody, cleanedBody) = extractNested(body)

                result += hoistedFromBody + declHeader + cleanedBody + "}"

                searchStart = closeBraceOffset + 1
            }
            return result
        }

        // Returns (hoisted, cleaned): every type declaration found ANYWHERE
        // in `slice` (recursing into deeper nesting first, so a
        // doubly-nested type is hoisted above its own immediate container,
        // which is in turn hoisted above the type that contained THAT) is
        // extracted into `hoisted`, in the order they should appear;
        // `cleaned` is `slice` with all of those declarations removed,
        // preserving whatever non-declaration text surrounded them.
        func extractNested(_ slice: [Character]) -> (hoisted: String, cleaned: String) {
            var hoisted = ""
            var cleaned = ""
            var searchStart = 0
            while searchStart < slice.count {
                let remaining = String(slice[searchStart...])
                let nsRemaining = remaining as NSString
                guard let match = declRegex.firstMatch(in: remaining, options: [], range: NSRange(location: 0, length: nsRemaining.length)) else {
                    cleaned += remaining
                    break
                }
                let matchStartInRemaining = match.range.location
                let matchEndInRemaining = match.range.location + match.range.length
                cleaned += String(remaining.prefix(matchStartInRemaining))

                let declTextChars = Array(slice[(searchStart + matchStartInRemaining)..<(searchStart + matchEndInRemaining)])
                let searchFromOpenBrace = searchStart + matchEndInRemaining
                guard let openBraceOffset = slice[searchFromOpenBrace...].firstIndex(of: "{") else {
                    cleaned += String(slice[(searchStart + matchStartInRemaining)...])
                    break
                }
                guard let closeBraceOffset = findMatchingBraceInChars(slice, openIdx: openBraceOffset) else {
                    cleaned += String(slice[(searchStart + matchStartInRemaining)...])
                    break
                }

                let declHeader = String(declTextChars) + String(slice[searchFromOpenBrace..<(openBraceOffset + 1)])
                let nestedBody = Array(slice[(openBraceOffset + 1)..<closeBraceOffset])
                let (innerHoisted, innerCleaned) = extractNested(nestedBody)

                hoisted += innerHoisted + declHeader + innerCleaned + "}\n\n"

                searchStart = closeBraceOffset + 1
            }
            return (hoisted, cleaned)
        }

        return processSequentially(Array(text))
    }

    private func findMatchingBraceInChars(_ chars: [Character], openIdx: Int) -> Int? {
        var depth = 0
        var i = openIdx
        var inString = false
        while i < chars.count {
            let c = chars[i]
            if inString {
                if c == "\\", i + 1 < chars.count { i += 2; continue }
                if c == "\"" { inString = false }
                i += 1
                continue
            }
            if c == "\"" {
                inString = true
            } else if c == "{" {
                depth += 1
            } else if c == "}" {
                depth -= 1
                if depth == 0 { return i }
            }
            i += 1
        }
        return nil
    }

    private func transpileStringInterpolation(text: String) -> String {
        let chars = Array(text)
        var result = ""
        var i = 0
        while i < chars.count {
            guard chars[i] == "\"" else {
                result.append(chars[i])
                i += 1
                continue
            }
            var literalBody = ""
            var hasInterpolation = false
            var j = i + 1
            while j < chars.count {
                if chars[j] == "\\", j + 1 < chars.count, chars[j + 1] == "(" {
                    hasInterpolation = true
                    var depth = 1
                    var k = j + 2
                    var exprChars: [Character] = []
                    while k < chars.count, depth > 0 {
                        if chars[k] == "(" { depth += 1 }
                        else if chars[k] == ")" {
                            depth -= 1
                            if depth == 0 { break }
                        }
                        exprChars.append(chars[k])
                        k += 1
                    }
                    literalBody += "${" + String(exprChars) + "}"
                    j = k + 1
                } else if chars[j] == "\\", j + 1 < chars.count {
                    literalBody.append(chars[j])
                    literalBody.append(chars[j + 1])
                    j += 2
                } else if chars[j] == "\"" {
                    break
                } else {
                    literalBody.append(chars[j])
                    j += 1
                }
            }
            if hasInterpolation {
                result += "`" + literalBody + "`"
            } else {
                result += "\"" + literalBody + "\""
            }
            i = min(j + 1, chars.count)
        }
        return result
    }

    public func transpileSwiftToJS(swift: String) -> String {
        var js = swift

        // Must run before everything else: converts `\(expr)` into `${expr}`
        // and switches the enclosing quotes to backticks, while leaving expr
        // itself as plain text so every later pass (argument-label stripping,
        // String(format:) conversion, self->this, etc.) still applies to it
        // exactly as it would anywhere else in the source.
        js = transpileStringInterpolation(text: js)

        // Hoist nested type declarations (e.g. a `private class Node {...}`
        // declared inside `class LRUCache {...}`, the standard Swift pattern
        // for a linked-list-node helper type used only by one containing
        // type) to stand-alone top-level declarations BEFORE their former
        // container. JS class bodies can only contain members (properties,
        // methods, accessors) — a nested `class Node {...}` directly inside
        // another class's body is not valid JS at all (it parses as an
        // unexpected identifier where a class member was expected). Hoisting
        // to a sibling declaration ahead of the outer class works because
        // JS classes are ordinary (TDZ-scoped) bindings in the same scope;
        // as long as `Node` is fully declared before `LRUCache`'s own body
        // runs (which happens at call time, not declaration time), any
        // `new Node(...)` inside `LRUCache` resolves correctly.
        js = hoistNestedTypeDeclarations(js)

        // Swift's discard pattern (`_ = someCall()`, meaning "run this and
        // throw away the result") has no JS equivalent — `_` isn't special
        // there, it's just an ordinary identifier. Left alone, `_ = expr`
        // becomes a real JS assignment to a variable literally named `_`.
        // That's merely wasteful on its own, but it becomes a genuine
        // infinite-loop bug when it appears inside a `for _ in 0..<5 { _ =
        // expr }` loop: the C-style loop this transpiles to also uses `_` as
        // its own counter variable, so the body's assignment overwrites the
        // loop counter itself with `expr`'s result on every iteration,
        // permanently detaching it from the loop's actual iteration count —
        // discovered empirically when this pattern hung the JS engine
        // indefinitely rather than just producing a wrong answer. Must run
        // before the for-loop conversions below. Strip it down to a bare
        // expression statement, which correctly discards the value exactly
        // like Swift's `_ =` does.
        js = replaceRegex(in: js, pattern: "\\b_\\s*=(?!=)\\s*", template: "")

        // 0. Clean .self and replace self -> this and nil -> null at the very beginning
        js = js.replacingOccurrences(of: ".self", with: "")
        js = replaceRegex(in: js, pattern: "\\bself\\b", template: "this")
        js = replaceRegex(in: js, pattern: "\\bnil\\b", template: "null")

        // 1. Clean protocol conformances in class/struct/actor declarations
        js = replaceRegex(in: js, pattern: "\\b(class|struct|actor)\\s+(\\w+(?:<[^>]+>)?)\\s*:\\s*[^{]+", template: "$1 $2 ")

        // 2. Access modifiers stripper before declarations
        js = replaceRegex(in: js, pattern: "\\b(public|private|internal|fileprivate)\\s+(class|struct|actor)\\b", template: "$2")

        // 2b. Access modifiers before property/method/init declarations (e.g.
        // `public var val: Int`, `public init(...)`) — previously only
        // stripped before class/struct/actor, never before let/var/func/init,
        // silently leaving a leading `public`/`internal`/`fileprivate` token
        // stuck in front of the property or method after later passes clean
        // up everything else around it, producing invalid JS class-field/
        // method syntax like `public val = null` or `public constructor(...)`.
        js = replaceRegex(in: js, pattern: "\\b(?:public|private|internal|fileprivate)\\s+((?:static\\s+)?(?:let|var|func|init)\\b)", template: "$1")

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

        // 4b. `Set<Type> = [array literal]` — must run BEFORE the type
        // annotation is discarded below, which otherwise loses the fact this
        // was ever a Set at all, leaving a bare JS array literal that has no
        // `.has()`/`.add()` methods (only `MockSet`/the real ES6 `Set` does).
        js = replaceRegex(in: js, pattern: ":\\s*Set\\s*<[^=]+>\\s*=\\s*(\\[[^\\]]*\\])", template: "= new Set($1)")

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
        // Preserves Swift default parameter values (`cost: Int = 1`) as JS
        // default parameters (`cost = 1`) — previously dropped entirely,
        // since only the type was discarded and the trailing `= 1` was
        // considered part of that discarded type text. That silently turned
        // every call site omitting the optional argument into a real
        // `undefined`, which then poisons any arithmetic/comparison it
        // touches (`Number(undefined)` is `NaN`, and `x >= NaN` is always
        // false) — discovered via a test harness calling `allowRequest(...)`
        // without its optional `cost:` argument, relying on the Swift
        // default, and getting a permanent `false` from every call.
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
                    guard let name = leftParts.last else { continue }
                    let rest = parts.dropFirst().joined(separator: ":")
                    if let eqRange = rest.range(of: "=") {
                        let defaultValue = rest[eqRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                        cleaned.append("\(name) = \(defaultValue)")
                    } else {
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

        // Flatten multi-condition guards (`guard !a.isEmpty, !b.isEmpty else
        // {...}`) into a single `&&`-joined condition BEFORE any of the
        // guard-specific regexes below run. Left alone, the plain-guard
        // regex captures the whole comma-separated condition as one group
        // and wraps it in a single `!(...)`, e.g. `!(!(a), !(b))` — valid JS,
        // but the comma there is the JS COMMA OPERATOR, which evaluates and
        // discards every operand except the last. That makes the first
        // condition silently unenforced (not a crash — a correctness bug
        // that only shows up as certain inputs slipping past a guard that
        // should have rejected them).
        js = transpileGuardMultiCondition(text: js)

        // Strip weak self / weak this and guard let self (MUST RUN BEFORE guard let)
        js = replaceRegex(in: js, pattern: "\\[\\s*weak\\s+(?:self|this)\\s*\\]", template: "")
        js = replaceRegex(in: js, pattern: "guard\\s+let\\s+this\\s*=\\s*this\\s+else\\s*\\{\\s*return\\s*\\}", template: "")
        js = replaceRegex(in: js, pattern: "guard\\s+let\\s+self\\s*=\\s*self\\s+else\\s*\\{\\s*return\\s*\\}", template: "")

        // Guard let and general guard (MUST RUN BEFORE trailing closures to avoid conflicts with if/guard braces)
        js = replaceRegex(in: js, pattern: "guard\\s+let\\s+(\\w+)\\s*=\\s*\\1\\s+else\\s*\\{\\s*return\\s*([^}]*)\\s*\\}", template: "if (!$1) { return $2; }")
        js = replaceRegex(in: js, pattern: "guard\\s+let\\s+(\\w+)\\s*=\\s*([^\\n{]+)\\s+else\\s*\\{\\s*return\\s*([^}]*)\\s*\\}", template: "const $1 = $2; if (!$1) { return $3; }")
        js = replaceRegex(in: js, pattern: "guard\\s+([^\\n{]+)\\s+else\\s*\\{\\s*return\\s*([^}]*)\\s*\\}", template: "if (!($1)) { return $2; }")

        // if let and if condition (MUST RUN BEFORE trailing closures to avoid conflicts with if braces)
        // Multi-condition form first (`if let x = expr, cond {`), same
        // reasoning as the `while let` fix above: without this, the
        // single-condition regex right below captures `expr, cond` as one
        // opaque value expression and assigns THAT (including the literal
        // comma and trailing condition text) to `x` — e.g. `if let seenIndex
        // = lastSeen[c], seenIndex >= start {` silently became `const
        // seenIndex = lastSeen[c], seenIndex >= start;`, a syntactically
        // broken statement, not just a wrong value.
        // `if boolCond, let x = expr, boolCond2 {` — the let-binding isn't
        // necessarily the FIRST clause; a plain boolean can precede it too
        // (e.g. `if nodes.count >= capacity, let lru = tail.prev, lru !==
        // head {`, from an LRU eviction check). Must run before the two
        // "let-binding-comes-first" cases below, which wouldn't match this
        // shape at all (they require `if let` immediately, not `if
        // someCondition, let`).
        js = replaceRegex(in: js, pattern: "if\\s+([^,{]+?),\\s*let\\s+(\\w+)\\s*=\\s*([^,{]+?),\\s*([^{]+?)\\s*\\{", template: "const $2 = $3; if (($1) && $2 !== undefined && $2 !== null && ($4)) {")
        js = replaceRegex(in: js, pattern: "if\\s+([^,{]+?),\\s*let\\s+(\\w+)\\s*=\\s*([^{]+?)\\s*\\{", template: "const $2 = $3; if (($1) && $2 !== undefined && $2 !== null) {")

        js = replaceRegex(in: js, pattern: "if\\s+let\\s+(\\w+)\\s*=\\s*([^,{]+?),\\s*([^{]+?)\\s*\\{", template: "const $1 = $2; if ($1 !== undefined && $1 !== null && ($3)) {")
        js = replaceRegex(in: js, pattern: "if\\s+let\\s+(\\w+)\\s*=\\s*([^{]+)\\{", template: "const $1 = $2; if ($1 !== undefined && $1 !== null) {")
        js = replaceRegex(in: js, pattern: "if\\s+([^({\\s][^{]+)\\s*\\{", template: "if ($1) {")

        // `.last` / `.first` properties (Array.last / Array.first in Swift,
        // returning the last/first element or nil if empty) — JS arrays have
        // no such property at all. Must run before the `while let` handling
        // right below, which commonly reads `arr.last` as the optional being
        // unwrapped (e.g. a monotonic-stack pattern: `while let top =
        // stack.last, ... { ... }`).
        js = replaceRegex(in: js, pattern: "(\\w+)\\.last\\b(?!\\()", template: "$1[$1.length - 1]")
        js = replaceRegex(in: js, pattern: "(\\w+)\\.first\\b(?!\\()", template: "$1[0]")

        // `while let x = expr, cond {` — MUST run before the bare
        // `while condition {` regex right below (which would otherwise treat
        // the entire `let x = expr, cond` as one opaque condition and wrap
        // it in parens without unwrapping anything). Unlike `if let`, this
        // can't just declare `x` once before the loop: Swift re-evaluates
        // `expr` (and `cond`) on every iteration, stopping as soon as `expr`
        // is nil or `cond` is false — equivalent to `while true { guard let x
        // = expr, cond else { break }; ...body }`. Reassigning `x` as part of
        // the loop's own condition (`(x = expr) !== undefined && ...`)
        // reproduces that per-iteration re-check; `x` needs a `let`
        // declaration immediately before the loop since JS has no way to
        // freshly declare a variable inside a `while(...)` condition itself.
        js = replaceRegex(in: js, pattern: "while\\s+let\\s+(\\w+)\\s*=\\s*([^,{]+?),\\s*([^{]+?)\\s*\\{", template: "var $1; while (($1 = $2) !== undefined && $1 !== null && ($3)) {")
        // Same, but without a trailing `, cond` — just `while let x = expr {`.
        js = replaceRegex(in: js, pattern: "while\\s+let\\s+(\\w+)\\s*=\\s*([^{]+?)\\s*\\{", template: "var $1; while (($1 = $2) !== undefined && $1 !== null) {")

        // Bare `while condition {` (mirrors the if-handling above; previously
        // missing entirely, so `while cond { ... }` without parentheses
        // around cond was invalid JS and threw a SyntaxError)
        js = replaceRegex(in: js, pattern: "while\\s+([^({\\s][^{]+)\\s*\\{", template: "while ($1) {")

        // enumerated (MUST RUN BEFORE trailing closures: `arr.enumerated() {`
        // otherwise matches the generic `.method(args) {` trailing-closure
        // pattern first, since it ends in exactly that shape, mangling it
        // into `arr.enumerated(, function() {...})` — invalid JS).
        // Emits `var`, not `let`/`const`, for the loop counter and per-item
        // binding: this runs before the later blanket `let`->`const` /
        // `var`->`let` swap (which exists to convert Swift's `let`/`var` into
        // JS `const`/`let`), and that blanket pass has no way to tell a
        // Swift-source token from one this template itself just emitted — a
        // literal `let i = 0` here would get caught by it and turned into
        // `const i = 0`, which throws on the loop's own `i++`.
        js = replaceRegex(in: js, pattern: "for\\s+\\(\\s*(\\w+)\\s*,\\s*(\\w+)\\s*\\)\\s+in\\s+(\\w+)\\.enumerated\\(\\)\\s*\\{", template: "for (var $1 = 0; $1 < $3.length; $1++) { var $2 = $3[$1];")

        // Range-based for loops (`for i in a...b {` / `for i in a..<b {`) —
        // MUST ALSO run before trailing closures for the exact same reason
        // as enumerated above: `for j in 1...n {` ends in `.n {` (the last
        // `.` of the `...`, followed by `n`, followed by `{`), which matches
        // trailing-closures' bare `.method {` pattern and mangles the loop
        // into a fake method call before this ever gets a chance to run.
        // Emits `var` for the same reason enumerated does (avoids the later
        // blanket `let`->`const` pass breaking the counter's mutability).
        // Bounds allow dotted paths (`chars.count`), not just a bare
        // identifier/number — `for end in 1...chars.count` previously left
        // the upper bound unmatched entirely (`\w+` doesn't include `.`),
        // so the whole loop fell through unconverted into later passes that
        // mangled it into nonsense like `for (...).length(function() {...`.
        js = replaceRegex(in: js, pattern: "for\\s+(\\w+)\\s+in\\s+([\\w.]+)\\s*\\.\\.\\.\\s*([\\w.]+)", template: "for (var $1 = $2; $1 <= $3; $1++)")
        js = replaceRegex(in: js, pattern: "for\\s+(\\w+)\\s+in\\s+([\\w.]+)\\s*\\.\\.<\\s*([\\w.]+)", template: "for (var $1 = $2; $1 < $3; $1++)")

        // Dictionary iteration with tuple destructuring, e.g. `for (_, group)
        // in groups {` (discarding the key) or `for (key, value) in dict {`
        // (using both) — must run BEFORE the plain single-variable for-in
        // below, since that regex's `(\w+)` wouldn't match the parenthesized
        // tuple pattern `(_, group)` at all and would otherwise leave this
        // completely unconverted.
        js = replaceRegex(in: js, pattern: "for\\s*\\(\\s*_\\s*,\\s*(\\w+)\\s*\\)\\s+in\\s+(\\w+)\\s*\\{", template: "for (const $1 of Object.values($2)) {")
        js = replaceRegex(in: js, pattern: "for\\s*\\(\\s*(\\w+)\\s*,\\s*(\\w+)\\s*\\)\\s+in\\s+(\\w+)\\s*\\{", template: "for (const [$1, $2] of Object.entries($3)) {")

        // Plain `for item in collection {` (direct iteration, no range or
        // .enumerated()) — previously had no handling anywhere in the
        // pipeline at all. Must run after the two range/enumerated regexes
        // above (so it only catches what's genuinely left) but still before
        // trailing closures, for the same collision reason.
        js = replaceRegex(in: js, pattern: "for\\s+(\\w+)\\s+in\\s+([^{]+?)\\s*\\{", template: "for (const $1 of $2) {")

        // Trailing closures (brace-counting based!)
        js = transpileTrailingClosures(text: js)

        // Task blocks (brace-counting based!)
        js = transpileTaskBlocks(text: js)

        // Closure assignments (e.g. onDataLoaded = { data in ... })
        // `\b` after `in` is required: without it, this pattern happily
        // matches just the first two letters of ANY identifier that starts
        // with "in" immediately after an opening brace with only whitespace
        // between them (e.g. `class TestCase {\n    intervals = ...` — the
        // capture group and the trailing `\s+` split the whitespace between
        // them however the engine needs to, and bare `in` then matches the
        // "in" that begins "intervals"). This corrupted the class
        // declaration itself, turning `class TestCase {` into `class
        // TestCase function( ) {` and truncating "intervals" to "tervals".
        js = replaceRegex(in: js, pattern: "\\{\\s*([a-zA-Z0-9_,\\s\\[\\]]+)\\s+in\\b", template: "function($1) {")

        // Convert deinit to deinit() {
        js = replaceRegex(in: js, pattern: "\\bdeinit\\s*\\{", template: "deinit() {")

        // Convert function methodName(...) async { -> async function methodName(...) {
        js = replaceRegex(in: js, pattern: "\\bfunction\\s+(\\w+)\\s*\\(([^)]*)\\)\\s*async\\s*\\{", template: "async function $1($2) {")

        // Strip try / try? / try!
        js = replaceRegex(in: js, pattern: "\\btry[?!]?\\s*", template: "")

        // do catch
        js = replaceRegex(in: js, pattern: "\\bdo\\s*\\{", template: "try {")
        js = replaceRegex(in: js, pattern: "\\bcatch\\s*\\{", template: "catch (error) {")

        // Optional-chaining ASSIGNMENT (`curr?.next = prev`) — valid Swift
        // (a no-op if `curr` is nil), but JS's `?.` can only be used to READ
        // or CALL through an optional chain; `a?.b = c` is an outright
        // SyntaxError there ("Invalid left-hand side in assignment"). Must
        // run before the general `?(` -> `?.(` conversion below, and before
        // any later pass that might otherwise treat this as a normal
        // assignment. Rewritten as a guarded assignment.
        js = replaceRegex(in: js, pattern: "(\\w+)\\?\\.(\\w+)\\s*=\\s*([^\\n;]+)", template: "if ($1) { $1.$2 = $3; }")

        // Convert Swift optional call ?( to JS ?.(
        js = js.replacingOccurrences(of: "?(", with: "?.(")

        // Array initializers (MUST RUN BEFORE the argument-label whitelist
        // below: that pass strips bare `repeating:`/`count:` labels wherever
        // they appear, since those names are in its whitelist. If it ran
        // first, by the time this regex looked for the literal text
        // `repeating:`/`count:` to match against, it would already be gone —
        // silently leaving `Array(repeating: X, count: Y)` never converted at
        // all and falling through to the generic class-instantiation pass as
        // `new Array(X, Y)`, which is wrong (that constructs a 2-element
        // array `[X, Y]`, not an X-filled array of length Y).
        js = replaceRegex(in: js, pattern: "Array\\s*\\(\\s*repeating\\s*:\\s*Array\\s*\\(\\s*repeating\\s*:\\s*([^,]+)\\s*,\\s*count\\s*:\\s*([^)]+)\\s*\\)\\s*,\\s*count\\s*:\\s*([^)]+)\\s*\\)", template: "Array.from({length: $3}, () => new Array($2).fill($1))")
        js = replaceRegex(in: js, pattern: "Array\\s*\\(\\s*repeating\\s*:\\s*([^,]+)\\s*,\\s*count\\s*:\\s*([^)]+)\\s*\\)", template: "new Array($2).fill($1)")
        // `[Type](repeating:count:)` — Swift's alternate spelling of the same
        // constructor (using the array TYPE itself as a callable instead of
        // the generic `Array` name, e.g. `[Bool](repeating: false, count: n)`)
        // — equally common, previously totally unhandled.
        js = replaceRegex(in: js, pattern: "\\[[\\w\\[\\]]+\\]\\s*\\(\\s*repeating\\s*:\\s*([^,]+)\\s*,\\s*count\\s*:\\s*([^)]+)\\s*\\)", template: "new Array($2).fill($1)")
        // Bare `Array(x)` (single argument, no `repeating:`/`count:` labels)
        // — Swift's "convert this String/Sequence into a real Array of its
        // elements" idiom (`Array(someString)` -> array of Characters).
        // `Array` is excluded from the generic auto-`new` pass below
        // specifically so this can be handled correctly here instead:
        // `new Array(x)` would be a completely different JS operation.
        js = replaceRegex(in: js, pattern: "(?<!new\\s)\\bArray\\s*\\(([^)]+)\\)", template: "Array.from($1)")

        // Strip argument labels in call sites
        js = replaceRegex(in: js, pattern: "\\b(string|url|until|timeIntervalSinceNow|at|with|from|forKey|forHTTPHeaderField|value|to|by|repeating|count|key|defaultValue|for|scheduler|receiveValue|in|userId|id|title|completed)\\s*:\\s*", template: "")

        // Strip & ampersand prefix
        js = replaceRegex(in: js, pattern: "&\\b", template: "")

        // Dictionary-with-default subscript idiom, e.g.
        // `groups[key, default: []].append(s)` — MUST run before the generic
        // dictionary-literal converter below, since its `[key, default: value]`
        // shape also contains a top-level colon and would otherwise be
        // misread as a dict literal itself. `array || default` correctly
        // falls back only when the entry is genuinely absent (`undefined`),
        // since even a previously-defaulted empty array `[]` is truthy in JS.
        // The default-value group allows one level of bracket nesting
        // (`(?:\[[^\]]*\]|[^\]])+` instead of plain `[^\]]+`) — the single
        // most common default value here is itself `[]`, whose own closing
        // `]` would otherwise prematurely terminate the capture and desync
        // the rest of the match, silently leaving the whole expression
        // unconverted. Leading `;` guards against JS's automatic-semicolon-
        // insertion: the preceding statement (typically `const key = ...`,
        // with no trailing semicolon, since neither Swift source nor this
        // transpiler's other passes add one) would otherwise have this
        // parenthesized expression parsed as a continuation — a function
        // call on whatever the previous line evaluated to — merging both
        // into one statement. That silently referenced `key` while still
        // inside its own initializer, throwing "Cannot access 'key' before
        // initialization" (a temporal-dead-zone error) instead of running
        // two separate statements as intended.
        js = replaceRegex(in: js, pattern: "(\\w+)\\[([^,\\]]+),\\s*default:\\s*((?:\\[[^\\]]*\\]|[^\\]])+)\\]\\.append\\(([^)]+)\\)", template: ";($1[$2] = $1[$2] || $3, $1[$2].push($4));")

        // Dictionary initializers
        js = replaceRegex(in: js, pattern: "\\[\\s*\\w+\\s*:\\s*\\w+\\s*\\]\\(\\)", template: "{}")
        js = replaceRegex(in: js, pattern: "\\[\\s*String\\s*:\\s*Set\\(\\)\\s*\\]", template: "{}")
        // Empty dictionary literal (e.g. `var nodes: [Int: Node] = [:]`) — had
        // no conversion path previously; only the `[Type: Type]()` call form did.
        js = replaceRegex(in: js, pattern: "\\[\\s*:\\s*\\]", template: "{}")

        // Empty typed array constructor (e.g. `[Character]()`, `[[Int]]()`) —
        // had no conversion path; the element type inside the brackets has no
        // JS meaning and must simply be dropped, leaving `[]`. Must run after
        // the dictionary-constructor regex above (`[Type: Type]()` -> `{}`)
        // since that one requires a colon and this one requires there be
        // none, so ordering between them doesn't matter, but both must run
        // before this could ever misfire on an already-converted `{}`.
        js = replaceRegex(in: js, pattern: "\\[\\s*[\\w\\[\\]]+\\s*\\]\\(\\)", template: "[]")

        // .append(x) -> .push(x) and .removeLast() -> .pop() — Array methods
        // with no JS equivalent name (JS arrays use push/pop for the same
        // stack-style operations Swift spells append/removeLast).
        js = replaceRegex(in: js, pattern: "\\.append\\(", template: ".push(")
        js = replaceRegex(in: js, pattern: "\\.removeLast\\(\\)", template: ".pop()")

        // Range subscript (`chars[start..<end]` / `chars[start...end]`) —
        // Swift's substring/subarray slicing syntax; JS's equivalent is
        // `.slice(start, end)` (half-open) — `...` needs its upper bound
        // adjusted by one since JS `.slice` end is always exclusive.
        js = replaceRegex(in: js, pattern: "(\\w+)\\[([\\w.]+)\\s*\\.\\.<\\s*([\\w.]+)\\]", template: "$1.slice($2, $3)")
        js = replaceRegex(in: js, pattern: "(\\w+)\\[([\\w.]+)\\s*\\.\\.\\.\\s*([\\w.]+)\\]", template: "$1.slice($2, ($3) + 1)")

        // `String(charsArray.slice(a, b))` / `String(s.sorted())` (already
        // rewritten to `s.slice().sort()` by this point) — Swift's "join an
        // Array of Characters back into a String" idiom. JS's
        // `String(anArray)` does something totally different (calls
        // Array.prototype.toString, joining elements with COMMAS —
        // `String(['a','b']) === "a,b"`, not `"ab"`), so this needs an
        // explicit empty-separator `.join('')` instead. Matches one or more
        // chained `.method(args)` calls (args may be empty, e.g. `.slice()`)
        // so it covers both a single `.slice(a, b)` and a chain like
        // `.slice().sort()`.
        js = replaceRegex(in: js, pattern: "\\bString\\s*\\(([\\w.]+(?:\\.\\w+\\([^)]*\\))+)\\)", template: "$1.join('')")

        // Set.contains(x) -> Set.has(x) — JS Sets use `has`, not `contains`.
        js = replaceRegex(in: js, pattern: "\\.contains\\(", template: ".has(")

        // .dropFirst() / .dropFirst(n) -> .slice(1) / .slice(n) — Array
        // method with no JS equivalent name (JS has no `.dropFirst`; `.slice`
        // with a single start index does the same "everything after index N"
        // slice, defaulting to dropping just the first element).
        js = replaceRegex(in: js, pattern: "\\.dropFirst\\(\\s*\\)", template: ".slice(1)")
        js = replaceRegex(in: js, pattern: "\\.dropFirst\\(([^)]+)\\)", template: ".slice($1)")

        // .joined() / .joined(separator: "x") -> .join() / .join("x") — same
        // method under a different name (`separator:` is already stripped to
        // a bare argument by the general call-site label stripper by this
        // point, or by the whitelist regex above if it ran first).
        js = replaceRegex(in: js, pattern: "\\.joined\\(", template: ".join(")

        // (expr).rounded() -> Math.round(expr) — Swift's Double.rounded()
        // method has no JS receiver-style equivalent; Math.round is a
        // top-level function taking the value as an argument instead.
        js = replaceRegex(in: js, pattern: "([\\w.]+|\\([^)\\n]+\\))\\.rounded\\(\\)", template: "Math.round($1)")

        // Non-empty dictionary literals (e.g. `[")": "(", "]": "["]`) — had no
        // conversion path at all previously (only the empty/constructor forms
        // above did), left as invalid `[key: value, ...]` array-bracket syntax
        // with colons inside. By this point in the pipeline all TYPE
        // annotations that could look similar (`[Character: Character]` on a
        // `let`/`var`/parameter/return type) have already been discarded
        // wholesale by earlier passes, so any `[...]` with a top-level colon
        // remaining here is a genuine data literal, safe to brace-convert.
        js = transpileDictionaryLiterals(text: js)

        // min / max — `[^,\n]`/`[^)\n]` (not just `[^,]`/`[^)]`) is
        // deliberate: without excluding newlines, these unbounded character
        // classes treat the ENTIRE REST OF THE FILE as fair game for a
        // greedy match, not just the current call's own arguments. Since
        // there's no shortage of later commas/parens anywhere in a file this
        // size (later method calls, the test harness's array literal, ...),
        // the regex would backtrack until it found SOME distant comma/paren
        // combination that satisfies the pattern — silently absorbing
        // unrelated code several lines away into `$2`/`$3` and corrupting
        // both statements. Restricting to same-line content is a safe
        // assumption here since every min/max call in this codebase's
        // solutions is written on a single line.
        js = replaceRegex(in: js, pattern: "(?<![A-Za-z0-9_\\.])min\\s*\\(\\s*([^,\\n]+)\\s*,\\s*([^,\\n]+)\\s*,\\s*([^)\\n]+)\\s*\\)", template: "Math.min($1, Math.min($2, $3))")
        js = replaceRegex(in: js, pattern: "(?<![A-Za-z0-9_\\.])min\\s*\\(\\s*([^,\\n]+)\\s*,\\s*([^)\\n]+)\\s*\\)", template: "Math.min($1, $2)")
        js = replaceRegex(in: js, pattern: "(?<![A-Za-z0-9_\\.])max\\s*\\(\\s*([^,\\n]+)\\s*,\\s*([^)\\n]+)\\s*\\)", template: "Math.max($1, $2)")

        // .sorted(by: >) / .sorted(by: <) — Swift operators passed as values
        // have no JS equivalent; there's no general way to transpile an
        // arbitrary operator-as-a-function-value, but `>`/`<` specifically
        // and unambiguously mean descending/ascending numeric order, so they
        // get a direct comparator. `.slice()` first (copy) preserves Swift's
        // non-mutating `sorted()` semantics instead of JS's in-place `.sort()`.
        // NOTE: `by:` is matched optionally — the argument-label whitelist a
        // few steps earlier already strips it (`by` is literally one of the
        // whitelisted label names, for unrelated Combine/URLSession calls),
        // so by the time this runs the text usually already reads
        // `.sorted(>)`, not `.sorted(by: >)`.
        js = replaceRegex(in: js, pattern: "\\.sorted\\s*\\(\\s*(?:by:\\s*)?>\\s*\\)", template: ".slice().sort((a, b) => b - a)")
        js = replaceRegex(in: js, pattern: "\\.sorted\\s*\\(\\s*(?:by:\\s*)?<\\s*\\)", template: ".slice().sort((a, b) => a - b)")
        // Bare `.sorted()` — JS's default `.sort()` already does correct
        // lexicographic ordering for strings/single-characters without a
        // comparator, matching Swift's default Comparable ordering for those
        // types (the only types this codebase calls bare `.sorted()` on).
        // Wraps the receiver in `Array.from(...)` rather than `.slice()`,
        // since Swift calls this on Strings too (`s.sorted()`, sorting a
        // String's characters into an Array) — `.slice()` on a JS String
        // returns another String, which has no `.sort()` method at all,
        // while `Array.from(x)` correctly produces a real array whether `x`
        // is already an array (copies it) or a string (splits into chars).
        js = replaceRegex(in: js, pattern: "([\\w.]+)\\.sorted\\s*\\(\\s*\\)", template: "Array.from($1).sort()")
        // `.sorted { closure }` (trailing-closure comparator form, e.g.
        // `intervals.sorted { $0[0] < $1[0] }`) — by this point in the
        // pipeline the trailing closure has already become
        // `.sorted(function(...) {...})`, but JS arrays have no `.sorted`
        // method at all (only `.sort`, which mutates in place); needs the
        // same non-mutating `.slice()` prefix as the operator-value forms above.
        js = replaceRegex(in: js, pattern: "\\.sorted\\s*\\(\\s*function", template: ".slice().sort(function")

        // .swapAt(i, j) — mutates the array in place swapping two indices;
        // no JS equivalent method exists, so expand to a destructuring swap.
        js = replaceRegex(in: js, pattern: "(\\w+)\\.swapAt\\(([^,\\n]+),\\s*([^)\\n]+)\\)", template: "[$1[$2], $1[$3]] = [$1[$3], $1[$2]]")

        // isEmpty / count
        js = js.replacingOccurrences(of: ".count", with: ".length")
        // `.isEmpty` -> `.length === 0` must be parenthesized as a whole unit,
        // not a bare textual substitution: `!x.isEmpty` correctly means
        // "!(x.length === 0)", but naively substituting just the `.isEmpty`
        // suffix produces `!x.length === 0`, which — because JS's unary `!`
        // binds tighter than `===` — actually parses as `(!x.length) === 0`.
        // That expression is a constant: `!x.length` is always a boolean, and
        // a boolean is never `=== 0` in JS, so the whole guard/if condition
        // this appears in becomes permanently true or false regardless of
        // the real input (this silently broke every `guard !x.isEmpty else
        // {...}` in the codebase, always taking the early-return branch).
        js = replaceRegex(in: js, pattern: "([\\w]+(?:\\.[\\w]+|\\[[^\\]]+\\]|\\([^)]*\\))*)\\.isEmpty", template: "($1.length === 0)")

        // let and var
        js = replaceRegex(in: js, pattern: "\\blet\\b", template: "const")
        js = replaceRegex(in: js, pattern: "\\bvar\\b", template: "let")

        // Class instantiations (including constructors with arguments,
        // properly paren-matched and with any argument labels stripped)
        js = transpileClassInstantiations(text: js)

        // Strip Swift force unwrap !
        js = replaceRegex(in: js, pattern: "\\b(\\w+\\([^)]*\\))!", template: "$1")
        // `x!.property` / `x!.method(...)` — force-unwrap immediately
        // followed by member access, e.g. `curr!.next`. Neither existing
        // case matches this: the first requires a preceding `(...)` call,
        // the second requires `!` to be followed by a comma/brace/bracket/
        // whitespace/end-of-string, none of which is a literal `.`.
        js = replaceRegex(in: js, pattern: "\\b(\\w+)!\\.", template: "$1.")
        js = replaceRegex(in: js, pattern: "\\b(\\w+)!([,\\}\\]\\s]|$)", template: "$1$2")

        return js
    }
}

