import Foundation
import JavaScriptCore

public protocol CodeRunnerProtocol {
    func runSwiftCode(code: String, appendHarness: String) async -> (stdout: String, stderr: String, exitCode: Int32)
    func runJSCode(code: String) -> String
    func transpileSwiftToJS(swift: String) -> String
}

public class CodeRunnerService: CodeRunnerProtocol {
    public init() {}
    
    public func runSwiftCode(code: String, appendHarness: String) async -> (stdout: String, stderr: String, exitCode: Int32) {
        #if os(macOS)
        let fullCode = code + "\n" + appendHarness
        
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
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = [tempFile.path]
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            
            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            
            return (stdout, stderr, process.terminationStatus)
        } catch {
            return ("", "Process execution failed: \(error.localizedDescription)\nEnsure Xcode CLI Tools are installed.", -2)
        }
        #else
        return ("", "Process execution not supported on this platform.", -2)
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
        
        let types = [": [[Character]]", ": [[Int]]", ": [Character]", ": [Int]", ": Int", ": Double", ": String", ": Bool", "-> Int", "-> Double", "-> String", "-> Bool"]
        for type in types {
            js = js.replacingOccurrences(of: type, with: "")
        }
        
        js = js.replacingOccurrences(of: "import Foundation", with: "")
        js = js.replacingOccurrences(of: "import SwiftUI", with: "")
        
        js = js.replacingOccurrences(of: ".count", with: ".length")
        js = js.replacingOccurrences(of: ".isEmpty", with: ".length === 0")
        
        let array2DRegex = try? NSRegularExpression(pattern: "Array\\s*\\(\\s*repeating\\s*:\\s*Array\\s*\\(\\s*repeating\\s*:\\s*([^,]+)\\s*,\\s*count\\s*:\\s*([^)]+)\\s*\\)\\s*,\\s*count\\s*:\\s*([^)]+)\\s*\\)", options: [])
        js = array2DRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "Array.from({length: $3}, () => Array($2).fill($1))") ?? js
        
        let array1DRegex = try? NSRegularExpression(pattern: "Array\\s*\\(\\s*repeating\\s*:\\s*([^,]+)\\s*,\\s*count\\s*:\\s*([^)]+)\\s*\\)", options: [])
        js = array1DRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "Array($2).fill($1)") ?? js
        
        let min3Regex = try? NSRegularExpression(pattern: "min\\s*\\(\\s*([^,]+)\\s*,\\s*([^,]+)\\s*,\\s*([^)]+)\\s*\\)", options: [])
        js = min3Regex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "Math.min($1, Math.min($2, $3))") ?? js
        
        let min2Regex = try? NSRegularExpression(pattern: "min\\s*\\(\\s*([^,]+)\\s*,\\s*([^)]+)\\s*\\)", options: [])
        js = min2Regex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "Math.min($1, $2)") ?? js
        
        let max2Regex = try? NSRegularExpression(pattern: "max\\s*\\(\\s*([^,]+)\\s*,\\s*([^)]+)\\s*\\)", options: [])
        js = max2Regex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "Math.max($1, $2)") ?? js
        
        let loopInclusiveRegex = try? NSRegularExpression(pattern: "for\\s+(\\w+)\\s+in\\s+(\\w+|\\d+)\\s*\\.\\.\\.\\s*(\\w+|\\d+)", options: [])
        js = loopInclusiveRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "for (let $1 = $2; $1 <= $3; $1++)") ?? js
        
        let loopExclusiveRegex = try? NSRegularExpression(pattern: "for\\s+(\\w+)\\s+in\\s+(\\w+|\\d+)\\s*\\.\\.<\\s*(\\w+|\\d+)", options: [])
        js = loopExclusiveRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "for (let $1 = $2; $1 < $3; $1++)") ?? js
        
        let paramCleanRegex = try? NSRegularExpression(pattern: "_\\s+(\\w+)", options: [])
        js = paramCleanRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "$1") ?? js
        
        js = js.replacingOccurrences(of: "func ", with: "")
        
        let letRegex = try? NSRegularExpression(pattern: "\\blet\\b", options: [])
        js = letRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "const") ?? js
        
        let varRegex = try? NSRegularExpression(pattern: "\\bvar\\b", options: [])
        js = varRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "let") ?? js
        
        let guardRegex = try? NSRegularExpression(pattern: "guard\\s+([^{]+)\\s+else\\s*\\{\\s*return\\s*([^}]*)\\s*\\}", options: [])
        js = guardRegex?.stringByReplacingMatches(in: js, options: [], range: NSRange(js.startIndex..., in: js), withTemplate: "if (!($1)) { return $2; }") ?? js
        
        return js
    }
}
