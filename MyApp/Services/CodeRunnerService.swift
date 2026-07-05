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

        function Double(v) { return Number(v); }
        function Float(v) { return Number(v); }
        function Int(v) { return parseInt(v, 10) || 0; }
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
    
    public func transpileSwiftToJS(swift: String) -> String {
        var js = swift
        
        js = js.replacingOccurrences(of: "import Foundation", with: "")
        js = js.replacingOccurrences(of: "import SwiftUI", with: "")
        js = js.replacingOccurrences(of: "import Dispatch", with: "")
        js = js.replacingOccurrences(of: "import Combine", with: "")
        
        // DispatchTime and Type cast replacements for JS execution
        js = js.replacingOccurrences(of: "DispatchTime.now()", with: "{ uptimeNanoseconds: Date.now() * 1000000 }")
        js = js.replacingOccurrences(of: "Double(", with: "Number(")
        js = js.replacingOccurrences(of: "Float(", with: "Number(")

        // Transpile Swift array / object equality (result == tc.expected -> JSON.stringify(result) === JSON.stringify(tc.expected))
        js = js.replacingOccurrences(of: "result == tc.expected", with: "JSON.stringify(result) === JSON.stringify(tc.expected)")

        // 1. String(format: "%.3f", expr) -> expr
        let stringFormatRegex = try? NSRegularExpression(pattern: "String\\s*\\(\\s*format\\s*:\\s*\"%\\.\\d+f\"\\s*,\\s*([^)]+)\\)", options: [])
        js = stringFormatRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "$1") ?? js
        
        // 2. Swift String Interpolation \(expr) -> " + (expr) + "
        let interpRegex = try? NSRegularExpression(pattern: "\\\\\\(([^)]+)\\)", options: [])
        js = interpRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "\" + ($1) + \"") ?? js
        
        // 3. Clean up double quotes concatenation: "" + or + ""
        js = js.replacingOccurrences(of: "\"\" + ", with: "")
        js = js.replacingOccurrences(of: " + \"\"", with: "")

        // 4. Numeric Underscores: e.g. 1_000_000.0 -> 1000000.0
        let numUnderscoreRegex = try? NSRegularExpression(pattern: "(\\d+)_(\\d+)", options: [])
        while (numUnderscoreRegex?.numberOfMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js)) ?? 0) > 0 {
            js = numUnderscoreRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "$1$2") ?? js
        }

        // 5. Strip struct definitions (e.g. struct TestCase { let nums: [Int]; ... })
        let structRegex = try? NSRegularExpression(pattern: "struct\\s+\\w+\\s*\\{[^}]*\\}", options: [.dotMatchesLineSeparators])
        js = structRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "") ?? js
        
        // 6. Replace struct instantiations: TestCase(...) -> {...} matching until closing paren before comma/newline/bracket
        let structInstRegex = try? NSRegularExpression(pattern: "\\bTestCase\\s*\\((.*?)\\)(?=\\s*[,\\}\\]\\n])", options: [.dotMatchesLineSeparators])
        js = structInstRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "{$1}") ?? js
        
        // 7. 2D Array initializers (BEFORE ANY TYPE STRIPPING!)
        let array2DRegex = try? NSRegularExpression(pattern: "Array\\s*\\(\\s*repeating\\s*:\\s*Array\\s*\\(\\s*repeating\\s*:\\s*([^,]+)\\s*,\\s*count\\s*:\\s*([^)]+)\\s*\\)\\s*,\\s*count\\s*:\\s*([^)]+)\\s*\\)", options: [])
        js = array2DRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "Array.from({length: $3}, () => Array($2).fill($1))") ?? js
        
        let array1DRegex = try? NSRegularExpression(pattern: "Array\\s*\\(\\s*repeating\\s*:\\s*([^,]+)\\s*,\\s*count\\s*:\\s*([^)]+)\\s*\\)", options: [])
        js = array1DRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "Array($2).fill($1)") ?? js
        
        // 8. Strip return types: -> [Int], -> String, -> [[Character]], -> Void, -> Int? etc.
        let returnTypeRegex = try? NSRegularExpression(pattern: "->\\s*[^{]+", options: [])
        js = returnTypeRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "") ?? js
        
        // 9. Strip parameter type annotations ONLY (matching Swift type names like Int, String, Character, Bool, Double)
        let paramTypeRegex = try? NSRegularExpression(pattern: ":\\s*\\[?\\[?\\s*(?:Int|String|Character|Bool|Double|Float|Void)\\]?\\s*\\]?\\??(?=[,\\)])", options: [])
        js = paramTypeRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "") ?? js
        
        // 10. Clean parameter label syntax: _ nums -> nums
        let paramCleanRegex = try? NSRegularExpression(pattern: "_\\s+(\\w+)", options: [])
        js = paramCleanRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "$1") ?? js
        
        // 11. Clean func keyword
        js = js.replacingOccurrences(of: "func ", with: "")
        
        // 12. Dictionary initializers: [Type: Type]() -> {}
        let dictInitRegex = try? NSRegularExpression(pattern: "\\[\\s*\\w+\\s*:\\s*\\w+\\s*\\]\\(\\)", options: [])
        js = dictInitRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "{}") ?? js
        
        // 13. min / max replacements (Negative lookbehind ensures Math.min isn't duplicated!)
        let min3Regex = try? NSRegularExpression(pattern: "(?<![A-Za-z0-9_\\.])min\\s*\\(\\s*([^,]+)\\s*,\\s*([^,]+)\\s*,\\s*([^)]+)\\s*\\)", options: [])
        js = min3Regex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "Math.min($1, Math.min($2, $3))") ?? js
        
        let min2Regex = try? NSRegularExpression(pattern: "(?<![A-Za-z0-9_\\.])min\\s*\\(\\s*([^,]+)\\s*,\\s*([^)]+)\\s*\\)", options: [])
        js = min2Regex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "Math.min($1, $2)") ?? js
        
        let max2Regex = try? NSRegularExpression(pattern: "(?<![A-Za-z0-9_\\.])max\\s*\\(\\s*([^,]+)\\s*,\\s*([^)]+)\\s*\\)", options: [])
        js = max2Regex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "Math.max($1, $2)") ?? js
        
        // 14. guard !matrix.isEmpty / isEmpty
        js = js.replacingOccurrences(of: "guard !matrix.isEmpty else { return 0 }", with: "if (matrix.length === 0) return 0;")
        js = js.replacingOccurrences(of: ".count", with: ".length")
        js = js.replacingOccurrences(of: ".isEmpty", with: ".length === 0")
        
        // 15. DispatchQueue trailing closures for JS execution
        let dispatchAsyncRegex = try? NSRegularExpression(pattern: "DispatchQueue\\.(main|global\\([^)]*\\))\\.async\\s*\\{([\\s\\S]*?)\\}", options: [])
        js = dispatchAsyncRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "DispatchQueue.$1.async(function() { $2 })") ?? js
        
        let dispatchAsyncAfterRegex = try? NSRegularExpression(pattern: "DispatchQueue\\.(main|global\\([^)]*\\))\\.asyncAfter\\([^)]+\\)\\s*\\{([\\s\\S]*?)\\}", options: [])
        js = dispatchAsyncAfterRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "DispatchQueue.$1.asyncAfter(null, function() { $2 })") ?? js
        
        // 16. Swift 'if let x = y {' -> 'const x = y; if (x !== undefined && x !== null) {' (MUST RUN BEFORE ifCondRegex!)
        let ifLetRegex = try? NSRegularExpression(pattern: "if\\s+let\\s+(\\w+)\\s*=\\s*([^{]+)\\{", options: [])
        js = ifLetRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "const $1 = $2; if ($1 !== undefined && $1 !== null) {") ?? js

        // 17. let and var to const and let
        let letRegex = try? NSRegularExpression(pattern: "\\blet\\b", options: [])
        js = letRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "const") ?? js
        
        let varRegex = try? NSRegularExpression(pattern: "\\bvar\\b", options: [])
        js = varRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "let") ?? js
        
        // 18. For loops (after let/var replacement so loop counter uses let!)
        let loopInclusiveRegex = try? NSRegularExpression(pattern: "for\\s+(\\w+)\\s+in\\s+(\\w+|\\d+)\\s*\\.\\.\\.\\s*(\\w+|\\d+)", options: [])
        js = loopInclusiveRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "for (let $1 = $2; $1 <= $3; $1++)") ?? js
        
        let loopExclusiveRegex = try? NSRegularExpression(pattern: "for\\s+(\\w+)\\s+in\\s+(\\w+|\\d+)\\s*\\.\\.<\\s*(\\w+|\\d+)", options: [])
        js = loopExclusiveRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "for (let $1 = $2; $1 < $3; $1++)") ?? js

        // 19. Swift 'if condition {' -> 'if (condition) {' (Runs AFTER ifLetRegex!)
        let ifCondRegex = try? NSRegularExpression(pattern: "if\\s+([^({\\s][^{]+)\\s*\\{", options: [])
        js = ifCondRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "if ($1) {") ?? js

        // 20. Swift 'for (i, tc) in testCases.enumerated() {' -> 'for (let i = 0; i < testCases.length; i++) { const tc = testCases[i];'
        let enumeratedRegex = try? NSRegularExpression(pattern: "for\\s+\\(\\s*(\\w+)\\s*,\\s*(\\w+)\\s*\\)\\s+in\\s+(\\w+)\\.enumerated\\(\\)\\s*\\{", options: [])
        js = enumeratedRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "for (let $1 = 0; $1 < $3.length; $1++) { const $2 = $3[$1];") ?? js

        // 21. Class instantiation without new
        let classInstRegex = try? NSRegularExpression(pattern: "(=\\s*)([A-Z]\\w*)\\(\\)", options: [])
        js = classInstRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "$1new $2()") ?? js
        
        // 22. guard else return
        let guardRegex = try? NSRegularExpression(pattern: "guard\\s+([^{]+)\\s+else\\s*\\{\\s*return\\s*([^}]*)\\s*\\}", options: [])
        js = guardRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "if (!($1)) { return $2; }") ?? js
        
        return js
    }
}
