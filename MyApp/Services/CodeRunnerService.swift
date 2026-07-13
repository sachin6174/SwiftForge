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
                },
                // Mocks the newer `try await URLSession.shared.data(from:)`
                // API (returns `(Data, URLResponse)` in real Swift) — a
                // 2-element array here so `const [data, response] = await
                // ...` (see the tuple-destructuring fix this pairs with)
                // works the same way Swift's positional `.0`/`.1` tuple
                // access would. No real network request happens in either
                // mock — this JS engine never had real networking at all,
                // only this same canned response shape `dataTask` already
                // used.
                data: async function(urlOrReq) {
                    var mockData = { userId: 1, id: 1, title: "delectus aut autem", completed: false };
                    var response = { statusCode: 200 };
                    return [mockData, response];
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

        // `type` is whatever survives `.self` stripping at the call site —
        // either the class itself (`Repository`) or a one-element array
        // literal containing it (`[Repository]`, from `[Repository].self`).
        // If that class carries a `__codingKeysMap` (see
        // extractAndStripCodingKeys), rename each mapped JSON key to its
        // Swift property name in place, on every decoded object.
        function __applyCodingKeysRename(parsed, type) {
            var actualType = Array.isArray(type) ? type[0] : type;
            var map = actualType && actualType.__codingKeysMap;
            if (!map) { return parsed; }
            function renameOne(o) {
                if (o && typeof o === 'object' && !Array.isArray(o)) {
                    for (var swiftKey in map) {
                        var jsonKey = map[swiftKey];
                        if (Object.prototype.hasOwnProperty.call(o, jsonKey)) {
                            o[swiftKey] = o[jsonKey];
                            if (swiftKey !== jsonKey) { delete o[jsonKey]; }
                        }
                    }
                }
            }
            if (Array.isArray(parsed)) { parsed.forEach(renameOne); } else { renameOne(parsed); }
            return parsed;
        }

        function JSONDecoder() {
            return {
                decode: function(type, data) {
                    var parsed;
                    if (typeof data === 'string') {
                        try { parsed = JSON.parse(data); } catch(e) { return data; }
                    } else {
                        parsed = data;
                    }
                    return __applyCodingKeysRename(parsed, type);
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
        // Swift's `Int(String)` is a FAILABLE initializer: it returns nil
        // (mapped to `undefined` here) unless the ENTIRE string is a valid
        // integer literal — unlike `parseInt`, which happily parses just a
        // leading numeric prefix (`parseInt("12abc", 10) === 12`) and falls
        // back to `NaN` (previously masked by `|| 0`, silently turning any
        // unparseable string into a valid-looking `0` instead of the nil a
        // caller's `if let`/`guard let` is specifically checking for).
        function Int(v) {
            if (typeof v === 'number') { return Math.trunc(v); }
            if (typeof v === 'string') {
                var t = v.trim();
                if (!/^[+-]?\\d+$/.test(t)) { return undefined; }
                return parseInt(t, 10);
            }
            return undefined;
        }

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

        // `fn` is routinely an `async function() {...}` (any `Task { ... }`
        // trailing closure transpiles to one) — calling it always returns a
        // Promise, which this mock previously discarded outright. Any
        // rejection from that discarded Promise (e.g. a thrown error deep
        // inside the task) became a silently-swallowed unhandled rejection:
        // `context.exceptionHandler` below only fires for SYNCHRONOUS
        // throws, never for a rejected Promise nobody observes, so an error
        // partway through a `Task { ... }` body — most commonly everything
        // AFTER its first `await` — simply stopped producing output with no
        // visible error at all, indistinguishable from the test harness
        // itself being broken. Attaching `.catch` here routes that failure
        // into the same `print`-based `logs` stream as every other error.
        //
        // Returns `{ value: p }` — Swift's `Task<Success, Never>` exposes its
        // eventual result via an async `.value` property (`for t in tasks {
        // if await t.value { ... } }`, this codebase's own concurrency test);
        // previously this mock returned nothing, leaving `.value` always
        // `undefined` and silently short-circuiting every such check to
        // false. Explicitly returning an object also makes this work
        // correctly when auto-`new`'d (`new Task(fn)`, which
        // `transpileClassInstantiations` applies to any bare capitalized
        // call it doesn't know is really a mocked function): `new` on a
        // function that explicitly returns an object uses THAT object
        // instead of discarding it for an empty `this`.
        function Task(fn) {
            var p = typeof fn === 'function' ? fn() : Promise.resolve(undefined);
            if (p && typeof p.catch === 'function') {
                p.catch(function(e) { print('JS Async Exception (Task): ' + e); });
            }
            return { value: p };
        }
        // Swift's `Task.yield()` (a static method, cooperatively yielding to
        // let other tasks run) had no mock at all — `Task` here is a bare
        // function value, not an object with static members, so `Task.yield`
        // was `undefined` and calling it threw `TypeError: Task.yield is not
        // a function`. Under the synchronous-mock execution model there's no
        // real scheduler to yield to, so resolving immediately (a no-op
        // `await`) is a faithful enough stand-in.
        Task.yield = function() { return Promise.resolve(); };
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

    // Strip `//` line comments before any other pass runs. Nothing else in
    // this pipeline is comment-aware — every later regex (the `if`/`guard`/
    // `while` condition-parenthesizers in particular) scans raw text for
    // keywords with no notion of "this is inside a comment". A comment like
    // `// even if right reached end but still scope to exclude...` contains
    // the bare word "if" with no `{` anywhere on the rest of that line; the
    // generic `if <cond> {` wrapper regex then greedily searches forward for
    // the next literal `{` in the ENTIRE file to close its capture group,
    // which can land arbitrarily far away (e.g. a struct declared much later
    // in the same file), silently swallowing and corrupting everything in
    // between into a malformed `if (...)`. String-literal-aware (mirrors
    // findMatchingBrace's escape/quote handling) so a legitimate `//` inside
    // a string, e.g. a `"https://..."` URL, is left untouched.
    private func stripLineComments(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        var inString = false
        var idx = text.startIndex
        while idx < text.endIndex {
            let char = text[idx]
            if inString {
                result.append(char)
                if char == "\\" {
                    idx = text.index(after: idx)
                    if idx < text.endIndex {
                        result.append(text[idx])
                        idx = text.index(after: idx)
                    }
                    continue
                }
                if char == "\"" { inString = false }
                idx = text.index(after: idx)
                continue
            }
            if char == "\"" {
                inString = true
                result.append(char)
                idx = text.index(after: idx)
                continue
            }
            if char == "/" {
                let nextIdx = text.index(after: idx)
                if nextIdx < text.endIndex && text[nextIdx] == "/" {
                    idx = nextIdx
                    while idx < text.endIndex && text[idx] != "\n" {
                        idx = text.index(after: idx)
                    }
                    continue
                }
            }
            result.append(char)
            idx = text.index(after: idx)
        }
        return result
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

    /// Quote-aware, linear-scan match for a parenthesized argument list —
    /// mirrors `findMatchingBrace` above, but for `(`/`)`. `startIndex` must
    /// point AT the opening `(`. Needed because a regex-based args capture
    /// like `[^)]*` (or even a "smarter" alternation of `"..."` vs `[^)]`)
    /// either truncates at the first `)` inside a quoted argument (e.g. a
    /// test-case name literally describing its own params in parens, `"Case
    /// (n=5)"`), or — when made "smart" about strings via an ambiguous
    /// alternation — invites catastrophic regex backtracking across a large
    /// transpiled file (confirmed: an alternation-based fix here made a full
    /// 24-question regression run hang for 10+ minutes instead of seconds).
    /// A manual character scan has neither failure mode and is linear time.
    private func findMatchingParen(text: String, startIndex: String.Index) -> String.Index? {
        var parenCount = 0
        var idx = startIndex
        var inString = false
        while idx < text.endIndex {
            let char = text[idx]
            if inString {
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
            } else if char == "(" {
                parenCount += 1
            } else if char == ")" {
                parenCount -= 1
                if parenCount == 0 {
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

    /// Splits `text` on top-level commas — i.e. not inside nested
    /// `()`/`[]`/`{}` or a string literal. Shared by `stripCallSiteLabels`
    /// (splitting call arguments) and `transpileGuardStatements` (splitting a
    /// guard's comma-separated conditions/bindings).
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
        // A ternary's `cond ? a : b` also puts a colon at depth 0, which is
        // otherwise indistinguishable from a dict literal's `key: value`
        // colon (e.g. `[matrix.count, matrix.isEmpty ? 0 : matrix[0].count]`
        // was misdetected as a dict and emitted as invalid JS `{...}`).
        // Ternary `?` is always surrounded by whitespace on both sides in
        // real Swift source, unlike optional chaining (`x?.y`, no space
        // before `.`), nil-coalescing (`x ?? y`, no space between `?`s), or
        // an optional type marker (`Int?`, no space before `?`) - so a
        // whitespace-delimited `?` reserves the next depth-0 colon for
        // itself instead of letting it count as a real dict colon.
        var pendingTernaryColons = 0
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
            case "?":
                if depth == 0, i > 0, chars[i - 1] == " ", i + 1 < chars.count, chars[i + 1] == " " {
                    pendingTernaryColons += 1
                }
            case ":":
                if depth == 0 {
                    if pendingTernaryColons > 0 {
                        pendingTernaryColons -= 1
                    } else {
                        return true
                    }
                }
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

    /// Applies `wrapImplicitReturnIfNeeded` to ordinary named function/method
    /// bodies, not just closures. Swift's implicit-return rule (a single-
    /// expression body auto-returns its value) applies equally to a
    /// single-expression `func`/method (`func currentBalance() -> Int {
    /// balance }`), but only closures got this treatment before — an
    /// ordinary function whose body is just one bare expression silently
    /// returned `undefined` from the JS equivalent. Matches `NAME(...) {
    /// BODY }` with NO nested braces in BODY at all (so a genuine
    /// multi-statement/control-flow body, which always contains its own
    /// nested `{}`, is never touched — `wrapImplicitReturnIfNeeded` also
    /// independently declines a body containing `;`/`\n`, so only a truly
    /// bare single expression is ever rewritten either way) — excludes
    /// control-flow keywords standing in for NAME (`if (cond) { stmt }`,
    /// `for (...) { ... }`, `constructor(...) { ... }`, ...), which would
    /// otherwise also match this same shape.
    private func wrapImplicitReturnForNamedBodies(_ text: String) -> String {
        let excludedNames: Set<String> = ["if", "for", "while", "switch", "catch", "function", "else", "do", "try", "return", "typeof", "new", "in", "of", "await", "async", "constructor", "deinit", "case", "default"]
        guard let regex = try? NSRegularExpression(pattern: "\\b(\\w+)\\s*\\(([^()]*)\\)\\s*\\{([^{}]*)\\}", options: []) else { return text }
        let ns = text as NSString
        var result = text
        var offset = 0
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        for m in matches {
            let name = ns.substring(with: m.range(at: 1))
            guard !excludedNames.contains(name) else { continue }
            let body = ns.substring(with: m.range(at: 3))
            let wrapped = wrapImplicitReturnIfNeeded(body)
            guard wrapped != body else { continue }
            let bodyRange = m.range(at: 3)
            let adjustedRange = NSRange(location: bodyRange.location + offset, length: bodyRange.length)
            if let targetRange = Range(adjustedRange, in: result) {
                result.replaceSubrange(targetRange, with: wrapped)
                offset += wrapped.count - bodyRange.length
            }
        }
        return result
    }

    /// Swift's `let (a, b) = await (asyncLetA, asyncLetB)` awaits multiple
    /// `async let` bindings together as a tuple — not valid JS syntax at all
    /// (no parenthesized tuple destructuring; `await (x, y)` is a comma
    /// expression that evaluates and discards every operand but the last).
    /// Splits both parenthesized comma lists (name-aware via
    /// `splitTopLevelCommas`) and re-emits one `const NAME = await VALUE;`
    /// per pair — awaiting each individually is equivalent, since Swift's
    /// structured concurrency only requires them to already be running
    /// concurrently, not to be awaited in one specific combined expression.
    private func transpileTupleAwaitDestructuring(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\b(?:let|const)\\s*\\(([^)]+)\\)\\s*=\\s*await\\s*\\(([^)]+)\\)", options: []) else { return text }
        let ns = text as NSString
        var result = text
        var offset = 0
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        for m in matches {
            let namesText = ns.substring(with: m.range(at: 1))
            let valuesText = ns.substring(with: m.range(at: 2))
            let names = splitTopLevelCommas(namesText).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let values = splitTopLevelCommas(valuesText).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard names.count == values.count, !names.isEmpty else { continue }
            let replacement = zip(names, values).map { "const \($0) = await \($1);" }.joined(separator: " ")
            let fullRange = m.range(at: 0)
            let adjustedRange = NSRange(location: fullRange.location + offset, length: fullRange.length)
            if let targetRange = Range(adjustedRange, in: result) {
                result.replaceSubrange(targetRange, with: replacement)
                offset += replacement.count - fullRange.length
            }
        }
        return result
    }

    /// Returns `"async function"` if `body` contains a top-level `await`,
    /// else plain `"function"`. `await` is only legal syntax inside an
    /// `async function` — a trailing closure whose body awaits something
    /// (e.g. this codebase's own test harness: `TestCase("...") { await
    /// runSomeAsyncCheck() }`) previously always got a plain, non-async
    /// `function() {...}` wrapper regardless, a hard `SyntaxError` at
    /// evaluation time (`Task {}` blocks were the one exception, already
    /// unconditionally emitting `async function` via transpileTaskBlocks).
    private func closureFunctionKeyword(for body: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\bawait\\b", options: []) else { return "function" }
        let ns = body as NSString
        return regex.firstMatch(in: body, options: [], range: NSRange(location: 0, length: ns.length)) != nil ? "async function" : "function"
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
        // The args list is located with `findMatchingParen` (a linear,
        // quote-aware scan — see its doc comment) rather than captured by
        // regex. A bare `[^)]*` args-capture stops at the FIRST `)` it sees,
        // including one that's just text INSIDE a quoted argument (e.g.
        // `TestCase(name: "Random Case (cap=7)") { ... }`, a test-case name
        // that happens to describe its own parameters in parens) — that
        // truncated match then fails to find `)\s*{` right after (the text
        // ends mid-string instead), so the WHOLE trailing closure silently
        // fails to convert for any such call, left as literal Swift closure
        // syntax, a hard JS SyntaxError at runtime. A regex "fix" attempting
        // to make the args-capture string-literal-aware via an alternation
        // (`"..."` vs `[^)]`, both repeated) was tried and reverted: the
        // ambiguity between the two alternatives (either can match ordinary
        // characters) invites catastrophic backtracking once the match
        // ultimately fails at a given start position (e.g. any ordinary
        // function call with no trailing `{`), which is common enough in a
        // large transpiled file to hang a full regression run for minutes.
        let pattern0 = "(?<![\\w.])([A-Z]\\w*)\\s*\\("
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
                // matchRange ends right after the opening '(' (pattern ends in `\(`).
                let openParenIdx = result.index(before: matchRange.upperBound)

                guard let closeParenIdx = findMatchingParen(text: result, startIndex: openParenIdx) else {
                    pos0 = result.index(after: openParenIdx)
                    continue
                }

                // Only a trailing-closure call if `{` immediately follows
                // the closing `)` (skipping whitespace) — otherwise this is
                // just an ordinary call/initializer with no closure at all.
                var afterParen = result.index(after: closeParenIdx)
                while afterParen < result.endIndex, result[afterParen] == " " || result[afterParen] == "\n" || result[afterParen] == "\t" {
                    afterParen = result.index(after: afterParen)
                }
                guard afterParen < result.endIndex, result[afterParen] == "{" else {
                    pos0 = result.index(after: openParenIdx)
                    continue
                }
                let openBraceIdx = afterParen

                let argsStart = result.index(after: openParenIdx)
                let args = String(result[argsStart..<closeParenIdx])

                if args.contains("function") {
                    pos0 = result.index(matchRange.lowerBound, offsetBy: match.range.length)
                    continue
                }

                guard let closeBraceIdx = findMatchingBrace(text: result, startIndex: openBraceIdx) else {
                    pos0 = result.index(after: openBraceIdx)
                    continue
                }

                let bodyStart = result.index(after: openBraceIdx)
                let body = String(result[bodyStart..<closeBraceIdx])
                // A closure-typed field routinely has a bare single-
                // expression body relying on Swift's implicit return (e.g.
                // this codebase's own `TestCase(name: ...) { await
                // someCheck() }`, matching a `run: () async -> Bool` field);
                // unlike pattern1/pattern2 below, this bare-type-constructor
                // form never got this treatment, silently always returning
                // `undefined` for such a closure.
                let wrappedBody = wrapImplicitReturnIfNeeded(body)
                let argsPrefix = args.isEmpty ? "" : "\(args), "
                let replacement = "\(typeName)(\(argsPrefix)\(closureFunctionKeyword(for: wrappedBody))() {\(wrappedBody)})"

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
                replacement = ".\(methodName)(\(args), \(closureFunctionKeyword(for: closureBody))(\(params)) {\(closureBody)})"
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
                replacement = ".\(methodName)(\(args), \(closureFunctionKeyword(for: wrappedBody))(\(params)) {\(wrappedBody)})"
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
                replacement = ".\(methodName)(\(closureFunctionKeyword(for: closureBody))(\(params)) {\(closureBody)})"
            } else {
                let shorthandParams = shorthandClosureParams(body)
                let wrappedBody = wrapImplicitReturnIfNeeded(body, forSortComparator: methodName == "sorted" || methodName == "sort")
                replacement = ".\(methodName)(\(closureFunctionKeyword(for: wrappedBody))(\(shorthandParams)) {\(wrappedBody)})"
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
            // `Task { await account.withdraw(30) }` (a bare single-expression
            // body, relying on Swift's implicit return to make the Task's
            // eventual `Task<Bool, Never>.value` meaningful) previously
            // always resolved to `undefined` here — no implicit-return
            // handling was ever applied to a `Task {}` body.
            let wrappedBody = wrapImplicitReturnIfNeeded(body)
            let replacement = "Task(async function() {\(wrappedBody)})"

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
    /// Finds the next WHOLE-WORD occurrence of `word` in `text` (not
    /// preceded or followed by another identifier character, so searching
    /// for "func" doesn't match inside "myFuncName"), starting at `from`.
    /// String.Index-based throughout (never NSRange/UTF-16 offsets), so it
    /// stays correct regardless of what characters appear earlier in the
    /// string — unlike mixing NSRegularExpression match offsets directly
    /// into String.Index arithmetic, which silently desyncs whenever the
    /// text contains any character outside the Basic Multilingual Plane.
    private func firstWholeWordRange(of word: String, in text: String, from: String.Index? = nil) -> Range<String.Index>? {
        var searchStart = from ?? text.startIndex
        while searchStart < text.endIndex, let found = text.range(of: word, range: searchStart..<text.endIndex) {
            let precededOK: Bool
            if found.lowerBound == text.startIndex {
                precededOK = true
            } else {
                let before = text[text.index(before: found.lowerBound)]
                precededOK = !(before.isLetter || before.isNumber || before == "_")
            }
            let followedOK: Bool
            if found.upperBound == text.endIndex {
                followedOK = true
            } else {
                let after = text[found.upperBound]
                followedOK = !(after.isLetter || after.isNumber || after == "_")
            }
            if precededOK && followedOK {
                return found
            }
            searchStart = text.index(after: found.lowerBound)
        }
        return nil
    }

    /// Extracts every TOP-LEVEL `func name(...) { ... }` definition (full
    /// verbatim text, signature through matching close brace) from `body`,
    /// via `findMatchingBrace` so a closure literal or nested control-flow
    /// block inside one method is never mistaken for a sibling method.
    private func extractTopLevelFuncs(from body: String) -> [String] {
        var results: [String] = []
        var searchFrom = body.startIndex
        while let range = firstWholeWordRange(of: "func", in: body, from: searchFrom) {
            guard let openBraceIdx = body[range.upperBound...].firstIndex(of: "{") else {
                break
            }
            guard let closeBraceIdx = findMatchingBrace(text: body, startIndex: openBraceIdx) else {
                break
            }
            results.append(String(body[range.lowerBound...closeBraceIdx]))
            searchFrom = body.index(after: closeBraceIdx)
        }
        return results
    }

    /// Extracts the method name from a `func name(...) { ... }` text span.
    private func firstFuncName(in funcText: String) -> String? {
        guard let range = firstWholeWordRange(of: "func", in: funcText) else { return nil }
        var idx = range.upperBound
        while idx < funcText.endIndex, funcText[idx] == " " { idx = funcText.index(after: idx) }
        var nameEnd = idx
        while nameEnd < funcText.endIndex, funcText[nameEnd].isLetter || funcText[nameEnd].isNumber || funcText[nameEnd] == "_" {
            nameEnd = funcText.index(after: nameEnd)
        }
        guard nameEnd > idx else { return nil }
        return String(funcText[idx..<nameEnd])
    }

    /// Erases every `protocol Name { ... }` declaration entirely — a
    /// protocol has no runtime representation in JS's duck-typed world at
    /// all (nothing enforces conformance there), so the requirement list
    /// itself (bare method signatures, `{ get }`/`{ get set }` property
    /// requirements, `@objc optional` members, ...) can simply be deleted
    /// regardless of its exact contents. Previously the bare `protocol`
    /// keyword was left completely untouched (not a JS keyword at all —
    /// "Unexpected identifier" as soon as the JS engine hit it), so ANY
    /// question using a protocol declaration failed outright, including one
    /// already-shipped question that was silently broken this way.
    ///
    /// Then redistributes default method implementations: an
    /// `extension SomeProtocol { func x() { ... } }` supplying a default
    /// implementation for one of that protocol's requirements — the
    /// standard protocol-oriented-programming pattern — has nothing to
    /// merge into once the protocol itself is erased (unlike an extension
    /// of a real type, which this transpiler already merges into that
    /// type's own class declaration elsewhere in the pipeline). Instead,
    /// each default method is copied into every `class`/`struct`/`actor`
    /// declared later in the same file whose conformance list mentions that
    /// protocol AND that doesn't already implement the method itself — so
    /// a conforming type that overrides the default keeps its own
    /// implementation, and one that doesn't gets the shared one for free,
    /// exactly matching Swift's own resolution order for this pattern.
    ///
    /// Must run BEFORE the generic protocol-conformance-list cleanup later
    /// in this pipeline (which strips a type's `: SomeProtocol` list
    /// entirely) — this pass still needs that list intact to know which
    /// types conform to which protocol.
    private func transpileProtocolDefaultImplementations(_ text: String) -> String {
        var result = text
        var protocolNames: Set<String> = []

        while let range = firstWholeWordRange(of: "protocol", in: result) {
            var idx = range.upperBound
            while idx < result.endIndex, result[idx] == " " { idx = result.index(after: idx) }
            var nameEnd = idx
            while nameEnd < result.endIndex, result[nameEnd].isLetter || result[nameEnd].isNumber || result[nameEnd] == "_" {
                nameEnd = result.index(after: nameEnd)
            }
            guard nameEnd > idx,
                  let openBraceIdx = result[nameEnd...].firstIndex(of: "{"),
                  let closeBraceIdx = findMatchingBrace(text: result, startIndex: openBraceIdx) else {
                break
            }
            let name = String(result[idx..<nameEnd])

            // Also swallow a leading `@objc ` attribute immediately before
            // `protocol`, if present, so it doesn't linger as dangling text.
            // `limitedBy:` avoids crashing when `deleteStart` is too close
            // to the start of the string to fit `objcPrefix` before it.
            var deleteStart = range.lowerBound
            let objcPrefix = "@objc "
            if let candidateStart = result.index(deleteStart, offsetBy: -objcPrefix.count, limitedBy: result.startIndex),
               result[candidateStart..<deleteStart] == objcPrefix {
                deleteStart = candidateStart
            }

            protocolNames.insert(name)
            result.removeSubrange(deleteStart...closeBraceIdx)
        }

        guard !protocolNames.isEmpty else { return result }

        var defaultMethods: [String: [String]] = [:]   // protocol name -> ["func x() { ... }", ...]
        var searchFrom = result.startIndex
        while let range = firstWholeWordRange(of: "extension", in: result, from: searchFrom) {
            var idx = range.upperBound
            while idx < result.endIndex, result[idx] == " " { idx = result.index(after: idx) }
            var nameEnd = idx
            while nameEnd < result.endIndex, result[nameEnd].isLetter || result[nameEnd].isNumber || result[nameEnd] == "_" {
                nameEnd = result.index(after: nameEnd)
            }
            guard nameEnd > idx, let openBraceIdx = result[nameEnd...].firstIndex(of: "{") else {
                searchFrom = result.index(after: range.lowerBound)
                continue
            }
            guard let closeBraceIdx = findMatchingBrace(text: result, startIndex: openBraceIdx) else {
                break
            }
            let name = String(result[idx..<nameEnd])

            guard protocolNames.contains(name) else {
                searchFrom = result.index(after: closeBraceIdx)
                continue
            }

            let body = String(result[result.index(after: openBraceIdx)..<closeBraceIdx])
            defaultMethods[name, default: []].append(contentsOf: extractTopLevelFuncs(from: body))

            result.removeSubrange(range.lowerBound...closeBraceIdx)
            searchFrom = range.lowerBound
        }

        guard !defaultMethods.isEmpty else { return result }

        for keyword in ["class", "struct", "actor"] {
            searchFrom = result.startIndex
            while let range = firstWholeWordRange(of: keyword, in: result, from: searchFrom) {
                var idx = range.upperBound
                while idx < result.endIndex, result[idx] == " " { idx = result.index(after: idx) }
                var nameEnd = idx
                while nameEnd < result.endIndex, result[nameEnd].isLetter || result[nameEnd].isNumber || result[nameEnd] == "_" {
                    nameEnd = result.index(after: nameEnd)
                }
                guard nameEnd > idx else {
                    searchFrom = result.index(after: range.lowerBound)
                    continue
                }

                var afterName = nameEnd
                while afterName < result.endIndex, result[afterName] == " " { afterName = result.index(after: afterName) }

                guard afterName < result.endIndex, result[afterName] == ":" else {
                    searchFrom = nameEnd
                    continue
                }

                let listStart = result.index(after: afterName)
                guard let openBraceIdx = result[listStart...].firstIndex(of: "{") else {
                    searchFrom = nameEnd
                    continue
                }
                guard let closeBraceIdx = findMatchingBrace(text: result, startIndex: openBraceIdx) else {
                    break
                }

                let conformanceListRaw = String(result[listStart..<openBraceIdx])
                let conformances = conformanceListRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

                let existingBody = String(result[result.index(after: openBraceIdx)..<closeBraceIdx])
                var toInject: [String] = []
                for conformance in conformances {
                    guard let methods = defaultMethods[conformance] else { continue }
                    for methodText in methods {
                        guard let methodName = firstFuncName(in: methodText) else { continue }
                        let alreadyImplemented = existingBody.range(of: "func \(methodName)(") != nil
                            || existingBody.range(of: "func \(methodName) (") != nil
                        if !alreadyImplemented {
                            toInject.append(methodText)
                        }
                    }
                }

                if !toInject.isEmpty {
                    let injection = "\n" + toInject.joined(separator: "\n") + "\n"
                    result.insert(contentsOf: injection, at: closeBraceIdx)
                    searchFrom = result.index(closeBraceIdx, offsetBy: injection.count)
                } else {
                    searchFrom = result.index(after: closeBraceIdx)
                }
            }
        }

        return result
    }

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

    /// Swift's `enum CodingKeys: String, CodingKey { case a, b; case c =
    /// "raw_c" }` nested inside a Codable type is pure decode-time metadata
    /// — never switched over or instantiated by any running code, only read
    /// by the real JSONDecoder to remap JSON keys to property names. Left
    /// alone it's a hard failure here: `transpileEnumDeclarations`'s enum
    /// regex requires the name to be followed directly by `{` (no `:
    /// String, CodingKey` conformance clause), so it never matches this
    /// shape at all, and the mocked `JSONDecoder().decode` has no type-aware
    /// remapping built in regardless. The raw `enum CodingKeys ... { case
    /// ... }` text survives untouched into the JS class body, where `case`
    /// isn't a valid class-member keyword — a hard `SyntaxError` (`enum` in
    /// property position, still expecting a `;` when `CodingKeys` shows up
    /// next).
    ///
    /// Strips every such nested CodingKeys enum from its containing type's
    /// body, returning the per-type rename map (Swift property name -> JSON
    /// key, only where the raw value actually differs from the case name —
    /// a same-named case needs no remapping) so `transpileSwiftToJS` can
    /// attach it to the corresponding JS class as `TypeName.__codingKeysMap`
    /// once that class exists, for the JSONDecoder mock to apply.
    private func extractAndStripCodingKeys(_ text: String) -> (text: String, mappings: [(typeName: String, map: [String: String])]) {
        guard let declRegex = try? NSRegularExpression(pattern: "\\b(?:private\\s+|public\\s+|internal\\s+|fileprivate\\s+)?(?:class|struct|actor)\\s+(\\w+)", options: []) else {
            return (text, [])
        }
        guard let codingKeysRegex = try? NSRegularExpression(pattern: "\\benum\\s+CodingKeys\\s*:[^{]*\\{", options: []) else {
            return (text, [])
        }

        var mappings: [(String, [String: String])] = []
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
            let typeName = nsRemaining.substring(with: match.range(at: 1))

            result += String(remaining.prefix(matchStartInRemaining))
            let declNameEnd = searchStart + matchEndInRemaining
            result += String(chars[(searchStart + matchStartInRemaining)..<declNameEnd])

            guard let openBraceOffset = chars[declNameEnd...].firstIndex(of: "{") else {
                result += String(chars[declNameEnd...])
                break
            }
            guard let closeBraceOffset = findMatchingBraceInChars(chars, openIdx: openBraceOffset) else {
                result += String(chars[declNameEnd...])
                break
            }

            result += String(chars[declNameEnd..<(openBraceOffset + 1)])
            var bodyChars = Array(chars[(openBraceOffset + 1)..<closeBraceOffset])

            let bodyString = String(bodyChars)
            let nsBodyString = bodyString as NSString
            if let ckMatch = codingKeysRegex.firstMatch(in: bodyString, options: [], range: NSRange(location: 0, length: nsBodyString.length)) {
                let ckOpenBrace = ckMatch.range.location + ckMatch.range.length - 1
                if let ckCloseBrace = findMatchingBraceInChars(bodyChars, openIdx: ckOpenBrace) {
                    let ckBody = String(bodyChars[(ckOpenBrace + 1)..<ckCloseBrace])
                    let map = parseCodingKeysCases(ckBody)
                    if !map.isEmpty {
                        mappings.append((typeName, map))
                    }
                    bodyChars.removeSubrange(ckMatch.range.location..<(ckCloseBrace + 1))
                }
            }

            result += String(bodyChars) + "}"
            searchStart = closeBraceOffset + 1
        }

        return (result, mappings)
    }

    private func parseCodingKeysCases(_ body: String) -> [String: String] {
        var map: [String: String] = [:]
        guard let caseKeywordRegex = try? NSRegularExpression(pattern: "\\bcase\\b", options: []) else { return map }
        let ns = body as NSString
        let matches = caseKeywordRegex.matches(in: body, options: [], range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return map }

        for (idx, m) in matches.enumerated() {
            let start = m.range.location + m.range.length
            let end = (idx + 1 < matches.count) ? matches[idx + 1].range.location : ns.length
            let segment = ns.substring(with: NSRange(location: start, length: end - start))
            for entry in splitTopLevelCommas(segment) {
                let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let eqRange = trimmed.range(of: "=") else { continue }
                let name = trimmed[trimmed.startIndex..<eqRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                var rawValue = trimmed[eqRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                if rawValue.hasPrefix("\""), rawValue.hasSuffix("\""), rawValue.count >= 2 {
                    rawValue = String(rawValue.dropFirst().dropLast())
                }
                if !name.isEmpty, rawValue != name {
                    map[name] = rawValue
                }
            }
        }
        return map
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

    /// Finds a `{...}` block's matching close brace, treating both `"..."`
    /// string literals AND `` `...` `` template literals (already produced by
    /// `transpileStringInterpolation`, which runs before anything else) as
    /// atomic/opaque — a `${expr}` interpolation inside a template literal
    /// contains its own literal `{`/`}` characters that must NOT be counted
    /// as real structural braces, or scanners built on top of this (like
    /// `convertSwitchBody` below) desync and misidentify where a `case`/
    /// `switch` body actually ends. `findMatchingBrace` (the older, more
    /// widely-used helper above) only skips `"..."`, not `` `...` ``, since
    /// none of its call sites previously needed to scan text containing a
    /// template literal with embedded braces — new code should prefer this
    /// version wherever converted output already contains backtick strings.
    private func findMatchingBraceTemplateAware(_ chars: [Character], openIdx: Int) -> Int? {
        var depth = 0
        var i = openIdx
        var inString = false
        var inTemplate = false
        while i < chars.count {
            let c = chars[i]
            if inString {
                if c == "\\", i + 1 < chars.count { i += 2; continue }
                if c == "\"" { inString = false }
                i += 1
                continue
            }
            if inTemplate {
                if c == "\\", i + 1 < chars.count { i += 2; continue }
                if c == "`" { inTemplate = false }
                i += 1
                continue
            }
            if c == "\"" { inString = true }
            else if c == "`" { inTemplate = true }
            else if c == "{" { depth += 1 }
            else if c == "}" {
                depth -= 1
                if depth == 0 { return i }
            }
            i += 1
        }
        return nil
    }

    /// Swift `Dictionary.count`/`.isEmpty` and `Array.count`/`.isEmpty` are
    /// the SAME source syntax, but Dictionaries transpile to plain JS
    /// objects (`{}`), which have no `.length` at all — the blanket
    /// `.count` -> `.length` / `.isEmpty` -> `.length === 0` substitutions
    /// later in the pipeline are correct for arrays but silently produce
    /// `undefined`/always-false for a dictionary (poisoning any comparison
    /// against it, e.g. an LRU cache's `nodes.count >= capacity` eviction
    /// check, which then NEVER evicts since `undefined >= n` is always
    /// false; or a topological-sort cycle check like `degreeMap.isEmpty`,
    /// which then ALWAYS reports "not empty" — `undefined === 0` is always
    /// false — silently turning every genuinely acyclic graph into a
    /// reported cycle). The transpiler has no general type inference, but a
    /// dictionary-typed `let`/`var` declares its type explicitly
    /// (`[KeyType: ValueType]`, always containing a top-level colon, unlike
    /// an Array's `[ElementType]`) — scanning for that BEFORE type
    /// annotations are stripped lets us collect just the names that are
    /// actually dictionaries, and rewrite `.count`/`.isEmpty` only for those
    /// (through any dotted prefix, e.g. `this.nodes.count`) to
    /// `Object.keys(x).length` / `(Object.keys(x).length === 0)` ahead of
    /// the generic passes, which then have nothing left to (wrongly) match
    /// for these specific names.
    private func rewriteDictionaryCountAccess(_ text: String) -> String {
        guard let typeRegex = try? NSRegularExpression(pattern: "\\b(?:let|var)\\s+(\\w+)\\s*:\\s*\\[[^\\[\\]:]+:[^\\[\\]]+\\]", options: []) else { return text }
        let ns = text as NSString
        let matches = typeRegex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        let dictNames = Set(matches.map { ns.substring(with: $0.range(at: 1)) })
        guard !dictNames.isEmpty else { return text }
        var result = text
        for name in dictNames {
            let escapedName = NSRegularExpression.escapedPattern(for: name)
            let countPattern = "\\b((?:\\w+\\.)*\(escapedName))\\.count\\b"
            result = replaceRegex(in: result, pattern: countPattern, template: "Object.keys($1).length")
            let isEmptyPattern = "\\b((?:\\w+\\.)*\(escapedName))\\.isEmpty\\b"
            result = replaceRegex(in: result, pattern: isEmptyPattern, template: "(Object.keys($1).length === 0)")
        }
        return result
    }

    /// Swift's `String.append(_:)` (append a Character/String) and
    /// `Array.append(_:)` (append an element) are different methods
    /// sharing the same name — the blanket `.append(x) -> .push(x)` rule
    /// later in the pipeline is correct for arrays but produces a hard
    /// runtime TypeError for a string (`"".push is not a function` — JS
    /// strings are immutable, with no `.push` method at all; confirmed via
    /// a `var current = ""; ...; current.append(char)` loop building up a
    /// word character-by-character, an extremely ordinary string-parsing
    /// idiom). The transpiler has no general type inference, but a
    /// string-typed `let`/`var` reveals itself either via an explicit
    /// `: String` annotation or — far more common in practice — a
    /// string-literal initializer (`var current = ""`); scanning for
    /// either BEFORE the blanket rule runs lets us rewrite just those
    /// names' `.append(x)` calls to `+= x` (string concatenation) ahead of
    /// it, the same "detect the specific typed names first" strategy
    /// `rewriteDictionaryCountAccess` above already uses for
    /// `.count`/`.isEmpty`. Like that function, this is a global (not
    /// scope-aware) name scan, so a name reused for a String in one scope
    /// and an Array in another would be misclassified — an accepted,
    /// pre-existing limitation shared with the dictionary case, not a new
    /// one introduced here.
    private func rewriteStringAppendCalls(_ text: String) -> String {
        guard let typeRegex = try? NSRegularExpression(pattern: "\\b(?:let|var)\\s+(\\w+)\\s*(?::\\s*String\\s*)?=\\s*\"", options: []) else { return text }
        let ns = text as NSString
        let matches = typeRegex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        let stringNames = Set(matches.map { ns.substring(with: $0.range(at: 1)) })
        guard !stringNames.isEmpty else { return text }
        var result = text
        for name in stringNames {
            let escapedName = NSRegularExpression.escapedPattern(for: name)
            let pattern = "\\b(\(escapedName))\\.append\\(([^)]+)\\)"
            result = replaceRegex(in: result, pattern: pattern, template: "$1 += $2")
        }
        return result
    }

    /// Converts a Swift `enum NAME { case a; case b(Int); ... }` (no raw
    /// values, only optional associated values — the only shape this
    /// codebase's questions currently use) into a JS class exposing one
    /// static factory method per case, each returning a tagged plain object
    /// `{ __case: 'CASENAME', values: [...args] }`. Also rewrites every
    /// leading-dot construction of that case (`.get(1)`, Swift's implicit-
    /// member-expression shorthand for `NAME.get(1)`, used throughout array/
    /// struct literals like `[.put(1,1), .get(1)]`) to the explicit
    /// `NAME.get(1)` form, since the transpiler has no type inference to
    /// resolve a bare leading dot on its own — this only works because at
    /// most one enum's worth of case names needs disambiguating per file in
    /// practice. The negative lookbehind (excluding a preceding word
    /// character, `)`, or `]`) avoids mistaking a GENUINE member access
    /// chain (`foo.get(1)`) for this shorthand.
    private func transpileEnumDeclarations(_ text: String) -> String {
        // Allows an optional protocol-conformance clause between the enum's
        // name and its opening brace (`enum NetworkingError: Error { ... }`,
        // `enum Op: Equatable { ... }`) — previously required the name to be
        // followed directly by `{` with only whitespace in between, so ANY
        // conformance at all silently left the whole enum unmatched and
        // untouched, surviving as raw `enum NAME: ... { case ... }` text
        // into the JS class body it ends up nested in. `case` isn't a valid
        // JS class-member keyword there, and `enum` alone reads as an
        // unterminated field name to the parser — a hard `SyntaxError`
        // ("Unexpected use of reserved word 'enum'"), discovered when a
        // plain `enum NetworkingError: Error { case invalidURL; ... }` (no
        // computed properties, otherwise identical in shape to every other
        // enum this pass already handles) failed exactly like that.
        guard let enumRegex = try? NSRegularExpression(pattern: "\\benum\\s+(\\w+)(?:\\s*:\\s*[^{]+)?\\s*\\{([^{}]*)\\}", options: []) else { return text }
        guard let caseRegex = try? NSRegularExpression(pattern: "\\bcase\\s+(\\w+)", options: []) else { return text }
        var result = text
        while true {
            let ns = result as NSString
            guard let match = enumRegex.firstMatch(in: result, options: [], range: NSRange(location: 0, length: ns.length)),
                  let matchRange = Range(match.range, in: result) else {
                break
            }
            let enumName = ns.substring(with: match.range(at: 1))
            let body = ns.substring(with: match.range(at: 2))

            let nsBody = body as NSString
            let caseMatches = caseRegex.matches(in: body, options: [], range: NSRange(location: 0, length: nsBody.length))
            let caseNames = caseMatches.map { nsBody.substring(with: $0.range(at: 1)) }

            var classBody = ""
            for caseName in caseNames {
                classBody += "static \(caseName)(...args) { return { __case: '\(caseName)', values: args }; }\n"
            }
            let replacement = "class \(enumName) {\n\(classBody)}"
            result.replaceSubrange(matchRange, with: replacement)

            for caseName in caseNames {
                let escapedCase = NSRegularExpression.escapedPattern(for: caseName)
                let patternWithParens = "(?<![\\w)\\].])\\.(\(escapedCase))\\b\\s*\\("
                result = replaceRegex(in: result, pattern: patternWithParens, template: "\(enumName).$1(")

                // A case with NO associated values is referenced in Swift
                // with NO parens at all (`.size`, not `.size()`) — but the
                // JS side represents EVERY case, payload or not, as a
                // static factory FUNCTION that must be CALLED to produce
                // the `{__case, values}` tagged object the switch-matching
                // logic below uniformly expects. The with-parens pattern
                // above only fires when Swift source already has `(`, so a
                // bare `.size` was previously left completely unmatched —
                // rewritten to just `Op.size` (a reference to the function
                // itself, never invoked) it would still be wrong; this adds
                // the call parens Swift's own source never needed.
                let patternNoParens = "(?<![\\w)\\].])\\.(\(escapedCase))\\b(?!\\s*\\()"
                result = replaceRegex(in: result, pattern: patternNoParens, template: "\(enumName).$1()")
            }
        }
        return result
    }

    /// Swift's `switch` has no fallthrough by default, but a converted JS
    /// `switch` does — every `case`/`default` body here gets a synthesized
    /// trailing `break;` (harmless even after a body that already ends in its
    /// own `return`/`continue`/`break`, since that just leaves unreachable
    /// dead code, not a syntax error). Scans `body` (the switch's own
    /// `{...}` interior) for TOP-LEVEL `case V1, V2, ...:` / `default:`
    /// boundaries — i.e. not inside a nested `{}`/`()`/`[]` or a string/
    /// template literal — since a case body routinely contains its own
    /// nested braces (an `if`, a `for`, ...) that must not be mistaken for
    /// another case boundary. Comma-separated case values (`case "A", "B":`)
    /// are split back out into individual `case "A": case "B":` labels,
    /// which is the direct JS equivalent (both fall into the same body).
    ///
    /// EVERY case/default body is wrapped in its own `{...}` block, even
    /// though a bare (unwrapped) case body would often work — two sibling
    /// `case` branches declaring a same-named `guard let`/`if let` binding
    /// (e.g. `case "REMOVE": guard let idx = ... else {...}` and `case
    /// "MARK": guard let idx = ... else {...}`, both mutually exclusive at
    /// runtime) are only safe to give the SAME slot to when execution
    /// naturally flows past the first branch's `let` before ever reaching
    /// the second's — which is exactly what does NOT happen in a switch:
    /// jumping straight to a later case's `let idx = ...` skips over an
    /// earlier case's `let idx = ...` entirely, landing in that shared
    /// variable's temporal dead zone (`ReferenceError: Cannot access 'idx'
    /// before initialization`) if `rescopeDuplicateDeclarations` had turned
    /// it into a reassignment expecting the first case's `let` to have
    /// already run. Each case getting its own nested block sidesteps this
    /// completely — `rescopeDuplicateDeclarations` then sees two separate,
    /// independent scopes and correctly leaves both `const`/`let`
    /// declarations alone.
    ///
    /// Also recognizes Swift's enum-with-associated-values pattern match
    /// (`case .get(let key):`, `case .put(let key, let value):` — the shape
    /// `transpileEnumDeclarations` above produces tagged `{__case, values}`
    /// objects for) via `switchExpr`, binding each `let NAME` to the
    /// corresponding `switchExpr.values[i]` at the top of that case's block
    /// and switching on `\(switchExpr).__case` instead of `switchExpr`
    /// itself (signaled back to the caller via the returned `usesEnumPattern`
    /// flag, since only the caller knows whether to append `.__case` to the
    /// switch header itself).
    private func convertSwitchBody(_ body: String, switchExpr: String) -> (converted: String, usesEnumPattern: Bool) {
        let chars = Array(body)

        func matchesKeyword(_ idx: Int, _ kw: String) -> Bool {
            let kwChars = Array(kw)
            guard idx + kwChars.count <= chars.count else { return false }
            for (offset, kc) in kwChars.enumerated() where chars[idx + offset] != kc { return false }
            if idx > 0 {
                let prev = chars[idx - 1]
                if prev.isLetter || prev.isNumber || prev == "_" { return false }
            }
            let afterIdx = idx + kwChars.count
            if afterIdx < chars.count {
                let next = chars[afterIdx]
                if next.isLetter || next.isNumber || next == "_" { return false }
            }
            return true
        }

        var boundaries: [(range: Range<Int>, isDefault: Bool, valuesText: String)] = []
        var i = 0
        var depth = 0
        var inString = false
        var inTemplate = false
        while i < chars.count {
            let c = chars[i]
            if inString {
                if c == "\\", i + 1 < chars.count { i += 2; continue }
                if c == "\"" { inString = false }
                i += 1
                continue
            }
            if inTemplate {
                if c == "\\", i + 1 < chars.count { i += 2; continue }
                if c == "`" { inTemplate = false }
                i += 1
                continue
            }
            if c == "\"" { inString = true; i += 1; continue }
            if c == "`" { inTemplate = true; i += 1; continue }
            if c == "{" || c == "(" || c == "[" { depth += 1; i += 1; continue }
            if c == "}" || c == ")" || c == "]" { depth -= 1; i += 1; continue }
            if depth == 0 {
                if matchesKeyword(i, "case") {
                    var j = i + 4
                    var localDepth = 0
                    var localInString = false
                    var colonIdx = -1
                    while j < chars.count {
                        let cj = chars[j]
                        if localInString {
                            if cj == "\\", j + 1 < chars.count { j += 2; continue }
                            if cj == "\"" { localInString = false }
                            j += 1
                            continue
                        }
                        if cj == "\"" { localInString = true; j += 1; continue }
                        if cj == "(" || cj == "[" { localDepth += 1; j += 1; continue }
                        if cj == ")" || cj == "]" { localDepth -= 1; j += 1; continue }
                        if cj == ":" && localDepth == 0 { colonIdx = j; break }
                        j += 1
                    }
                    if colonIdx == -1 { i += 4; continue }
                    let valuesText = String(chars[(i + 4)..<colonIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                    boundaries.append((i..<(colonIdx + 1), false, valuesText))
                    i = colonIdx + 1
                    continue
                } else if matchesKeyword(i, "default") {
                    var j = i + 7
                    while j < chars.count, chars[j] != ":" { j += 1 }
                    if j < chars.count {
                        boundaries.append((i..<(j + 1), true, ""))
                        i = j + 1
                        continue
                    }
                }
            }
            i += 1
        }

        guard !boundaries.isEmpty else { return (body, false) }

        let enumPatternRegex = try! NSRegularExpression(pattern: "^\\.(\\w+)\\s*(?:\\((.*)\\))?$", options: [.dotMatchesLineSeparators])
        var usesEnumPattern = false

        var output = ""
        for (idx, b) in boundaries.enumerated() {
            let caseBodyStart = b.range.upperBound
            let caseBodyEnd = (idx + 1 < boundaries.count) ? boundaries[idx + 1].range.lowerBound : chars.count
            let caseBody = String(chars[caseBodyStart..<caseBodyEnd])
            if b.isDefault {
                output += "default: {\(caseBody)\nbreak;\n}"
                continue
            }

            let values = splitTopLevelCommas(b.valuesText).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            var caseLabels = ""
            var bindingDecls = ""
            for v in values {
                let ns = v as NSString
                if let m = enumPatternRegex.firstMatch(in: v, options: [], range: NSRange(location: 0, length: ns.length)) {
                    usesEnumPattern = true
                    let caseName = ns.substring(with: m.range(at: 1))
                    caseLabels += "case '\(caseName)': "
                    if m.range(at: 2).location != NSNotFound {
                        let paramsText = ns.substring(with: m.range(at: 2))
                        let bindings = splitTopLevelCommas(paramsText).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        for (paramIdx, binding) in bindings.enumerated() where binding.hasPrefix("let ") {
                            let name = String(binding.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
                            bindingDecls += "const \(name) = \(switchExpr).values[\(paramIdx)]; "
                        }
                    }
                } else {
                    caseLabels += "case \(v): "
                }
            }
            output += "\(caseLabels){\(bindingDecls)\(caseBody)\nbreak;\n}"
        }
        return (output, usesEnumPattern)
    }

    /// Converts `switch EXPR { case ... }` into JS's equivalent, locating the
    /// switch's own `{...}` via brace-matching (so nested braces in case
    /// bodies don't confuse the boundary) and delegating case-splitting to
    /// `convertSwitchBody`. Must run before any pass that would otherwise
    /// misparse a bare `case "X":` label (none currently do, but this keeps
    /// case bodies — which may themselves contain `guard`/`if let`/loops —
    /// intact as ordinary statement text for every later pass to process
    /// exactly like any other code).
    private func transpileSwitchStatements(_ text: String) -> String {
        guard let headerRegex = try? NSRegularExpression(pattern: "\\bswitch\\s+([^{]+?)\\s*\\{", options: []) else { return text }
        var result = text
        var searchPos = result.startIndex
        while searchPos < result.endIndex {
            let remainingRange = NSRange(searchPos..., in: result)
            guard let match = headerRegex.firstMatch(in: result, options: [], range: remainingRange),
                  let matchRange = Range(match.range, in: result),
                  let exprRange = Range(match.range(at: 1), in: result) else {
                break
            }
            let switchExpr = String(result[exprRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard let openBraceIdx = result[matchRange.lowerBound...].firstIndex(of: "{") else {
                searchPos = result.index(after: matchRange.lowerBound)
                continue
            }
            let charsFromOpen = Array(result[openBraceIdx...])
            guard let closeOffsetInSlice = findMatchingBraceTemplateAware(charsFromOpen, openIdx: 0) else {
                searchPos = result.index(after: openBraceIdx)
                continue
            }
            let closeBraceIdx = result.index(openBraceIdx, offsetBy: closeOffsetInSlice)

            let bodyStart = result.index(after: openBraceIdx)
            let body = String(result[bodyStart..<closeBraceIdx])
            let (convertedBody, usesEnumPattern) = convertSwitchBody(body, switchExpr: switchExpr)
            let discriminant = usesEnumPattern ? "\(switchExpr).__case" : switchExpr
            let replacement = "switch (\(discriminant)) {\(convertedBody)}"

            let prefix = result[..<matchRange.lowerBound]
            let suffix = result[result.index(after: closeBraceIdx)...]
            result = prefix + replacement + suffix

            searchPos = result.index(result.startIndex, offsetBy: prefix.count + replacement.count)
        }
        return result
    }

    /// General `guard COND else { BLOCK }` -> `if (!(COND)) { BLOCK }`
    /// conversion, replacing the three previous regex-based guard handlers
    /// (which only recognized an else-block whose ENTIRE content was a
    /// single literal `return ...` statement). Those couldn't represent a
    /// guard whose else-block does anything else — most commonly `continue`
    /// inside a `for` loop, or multiple statements before the exit — since
    /// `[^}]*` captured "the rest of the else block" as an opaque blob that
    /// was then required to start with the literal word `return`. Uses
    /// brace-matching (via the existing string-aware `findMatchingBrace`) to
    /// capture the else-block's true extent regardless of its contents, and
    /// `splitTopLevelCommas` (shared with the existing multi-condition `if
    /// let` handling) to support Swift's comma-separated guard clauses,
    /// mixing plain boolean conditions with `let NAME = EXPR` bindings in any
    /// order (`guard boolCond, let x = expr, boolCond2 else {`). A `let`
    /// clause becomes a `const` declared just before the check (not
    /// conditionally short-circuited the way Swift itself would evaluate it —
    /// acceptable here since no clause in this codebase's guards depends on
    /// an earlier clause having already failed to make a later expression
    /// merely SAFE to evaluate, only to make it MEANINGFUL); the guard fails
    /// (executing BLOCK) if any boolean clause is false or any binding is
    /// nil.
    ///
    /// The condition-matching group allows a complete backtick-quoted
    /// segment as an alternative to "any non-brace character" — a guard's
    /// CONDITION (not just its body) routinely contains string interpolation
    /// (`guard let url = URL(string: "...\(username)...")`), which
    /// `transpileStringInterpolation` has already converted to a backtick
    /// template literal by the time this pass runs, and `${...}` is a
    /// literal `{`/`}` pair the naive "stop at any brace" version couldn't
    /// tell apart from the guard's own `else {`. Left unhandled, the header
    /// regex simply never matched this guard at all, leaving the raw
    /// `guard`/`else` keywords in the output — neither is valid JS.
    private func transpileGuardStatements(_ text: String) -> String {
        guard let headerRegex = try? NSRegularExpression(pattern: "\\bguard\\s+((?:`[^`]*`|[^{])+?)\\s+else\\s*\\{", options: []) else { return text }
        // Also matches `guard var x = expr` (a mutable-copy optional
        // binding) alongside the far more common `guard let` — same
        // reasoning as the `if var` fix nearby: without this, `guard var`
        // fell all the way through unrecognized, since this was the only
        // place a guard's binding clause is actually parsed.
        let letClauseRegex = try? NSRegularExpression(pattern: "^(let|var)\\s+(\\w+)\\s*=\\s*(.+)$", options: [.dotMatchesLineSeparators])

        var result = text
        var searchPos = result.startIndex
        while searchPos < result.endIndex {
            let remainingRange = NSRange(searchPos..., in: result)
            guard let match = headerRegex.firstMatch(in: result, options: [], range: remainingRange),
                  let matchRange = Range(match.range, in: result),
                  let condRange = Range(match.range(at: 1), in: result) else {
                break
            }
            let condText = String(result[condRange])

            // The header regex's own match already ends exactly at (and
            // including) the else-block's opening brace — deriving it from
            // `matchRange.upperBound` directly, rather than re-searching
            // for "the first `{` from the guard's start", matters as soon
            // as the condition itself legitimately contains a `{` (a guard
            // whose condition contains string interpolation, already
            // converted to a `${...}` backtick template literal by this
            // point in the pipeline): that naive re-search found the WRONG
            // brace — the one inside `${...}` — and paired it with
            // `findMatchingBrace`'s corresponding (also wrong) close brace,
            // producing a mangled, duplicated fragment of the condition
            // text in the output instead of the real else-block.
            let openBraceIdx = result.index(before: matchRange.upperBound)
            guard let closeBraceIdx = findMatchingBrace(text: result, startIndex: openBraceIdx) else {
                searchPos = result.index(after: matchRange.lowerBound)
                continue
            }
            let bodyStart = result.index(after: openBraceIdx)
            let body = String(result[bodyStart..<closeBraceIdx])

            let clauses = splitTopLevelCommas(condText).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            var declarations: [String] = []
            var failConditions: [String] = []
            for clause in clauses {
                if let letClauseRegex,
                   let m = letClauseRegex.firstMatch(in: clause, options: [], range: NSRange(location: 0, length: (clause as NSString).length)) {
                    let ns = clause as NSString
                    let keyword = ns.substring(with: m.range(at: 1))
                    let name = ns.substring(with: m.range(at: 2))
                    let expr = ns.substring(with: m.range(at: 3))
                    let jsKeyword = keyword == "var" ? "let" : "const"
                    declarations.append("\(jsKeyword) \(name) = \(expr);")
                    failConditions.append("(\(name) === undefined || \(name) === null)")
                } else if !clause.isEmpty {
                    failConditions.append("!(\(clause))")
                }
            }
            let declText = declarations.joined(separator: " ")
            let condJoined = failConditions.joined(separator: " || ")
            let replacement = "\(declText) if (\(condJoined)) {\(body)}"

            let prefix = result[..<matchRange.lowerBound]
            let suffix = result[result.index(after: closeBraceIdx)...]
            result = prefix + replacement + suffix

            searchPos = result.index(result.startIndex, offsetBy: prefix.count + replacement.count)
        }
        return result
    }

    /// Fixes a class of bugs where the SAME variable name is declared twice
    /// via `const`/`let` in what is really the same JS scope, throwing
    /// `SyntaxError: Identifier 'x' has already been declared` (or, for two
    /// `const`s, "Cannot declare a const variable twice"). This routinely
    /// happens because Swift lets a name be reused freely across sibling
    /// statements/branches within one function — most commonly an `if let
    /// node = dict[key] { ...; return }` early-exit followed later in the
    /// SAME function by a plain `let node = ...` (e.g. `LRUCache.put`: check
    /// the cache, and if absent, create a new entry named `node` again) — but
    /// the earlier `if let`/`guard let` conversions above emit their
    /// synthesized `const NAME = ...` at the ENCLOSING scope (not nested
    /// inside the `if`'s own `{}`, since only the condition check itself is
    /// conditional, not the binding), so two such bindings sharing a name
    /// collide exactly as if hand-written that way. The same pattern occurs
    /// between sibling `case` branches of one `switch` that each declare a
    /// same-named `guard let`/`if let` binding (mutually exclusive at
    /// runtime, so reusing one slot is always safe).
    ///
    /// For each `{...}` scope (recursing into nested ones independently, so
    /// declarations in genuinely different blocks are never conflated), finds
    /// every direct-level (not inside a further-nested `{}`) `const`/`let`
    /// declaration; for any name declared more than once at that level,
    /// rewrites the FIRST occurrence's keyword to `let` (so it can be
    /// reassigned) and drops the keyword entirely from every later
    /// occurrence (turning it into a plain reassignment). Declarations inside
    /// an unmatched `(...)` — i.e. a `for (let i = 0; ...)` loop header,
    /// which the JS spec scopes to the loop itself, not the enclosing block —
    /// are deliberately excluded from this same-level counting; two sibling
    /// `for` loops each declaring their own `let i` is completely ordinary
    /// and must be left untouched, or turning the second one's declaration
    /// into a bare `i = 0` would reference an `i` that was never actually
    /// declared in the enclosing scope (a ReferenceError in strict mode).
    private func rescopeDuplicateDeclarations(_ text: String) -> [Character] {
        return processDeclScope(Array(text))
    }

    private func processDeclScope(_ chars: [Character]) -> [Character] {
        enum Piece {
            case text([Character])
            case block([Character]) // includes the surrounding `{`/`}`
        }

        var pieces: [Piece] = []
        var i = 0
        var textRun: [Character] = []
        while i < chars.count {
            let c = chars[i]
            if c == "\"" || c == "`" {
                let quote = c
                textRun.append(c)
                var j = i + 1
                while j < chars.count {
                    textRun.append(chars[j])
                    if chars[j] == "\\", j + 1 < chars.count {
                        j += 1
                        textRun.append(chars[j])
                        j += 1
                        continue
                    }
                    if chars[j] == quote { j += 1; break }
                    j += 1
                }
                i = j
                continue
            }
            if c == "{" {
                if let closeIdx = findMatchingBraceInChars(chars, openIdx: i) {
                    if !textRun.isEmpty { pieces.append(.text(textRun)); textRun = [] }
                    pieces.append(.block(Array(chars[i...closeIdx])))
                    i = closeIdx + 1
                    continue
                }
            }
            textRun.append(c)
            i += 1
        }
        if !textRun.isEmpty { pieces.append(.text(textRun)) }

        // Find declarations at THIS level only, tracking paren/bracket depth
        // (within each text piece) so a for-loop-header declaration —
        // textually at this same brace level, since it sits before the
        // loop's own `{` — is correctly excluded: it's scoped to the loop by
        // the JS spec, not to the enclosing block.
        let declRegex = try! NSRegularExpression(pattern: "\\b(const|let)\\s+(\\w+)\\s*=", options: [])

        func topLevelMatches(in s: String) -> [NSTextCheckingResult] {
            let ns = s as NSString
            let all = declRegex.matches(in: s, range: NSRange(location: 0, length: ns.length))
            guard !all.isEmpty else { return [] }
            let sChars = Array(s)
            var depthAtIndex = [Int](repeating: 0, count: sChars.count + 1)
            var depth = 0
            var inString = false
            for (idx, c) in sChars.enumerated() {
                depthAtIndex[idx] = depth
                if inString {
                    if c == "\"" { inString = false }
                    continue
                }
                if c == "\"" { inString = true }
                else if c == "(" || c == "[" { depth += 1 }
                else if c == ")" || c == "]" { depth -= 1 }
            }
            depthAtIndex[sChars.count] = depth
            return all.filter { depthAtIndex[$0.range.location] == 0 }
        }

        var nameCounts: [String: Int] = [:]
        for piece in pieces {
            if case .text(let t) = piece {
                for m in topLevelMatches(in: String(t)) {
                    let name = (String(t) as NSString).substring(with: m.range(at: 2))
                    nameCounts[name, default: 0] += 1
                }
            }
        }
        let duplicateNames = Set(nameCounts.filter { $0.value > 1 }.keys)

        var seenFirst: Set<String> = []
        var result: [Character] = []
        for piece in pieces {
            switch piece {
            case .text(let t):
                if duplicateNames.isEmpty {
                    result += t
                    continue
                }
                let s = String(t)
                let ns = s as NSString
                let matches = topLevelMatches(in: s)
                if matches.isEmpty {
                    result += t
                    continue
                }
                var rebuilt = ""
                var lastEnd = 0
                for m in matches {
                    let name = ns.substring(with: m.range(at: 2))
                    let fullRange = m.range(at: 0)
                    rebuilt += ns.substring(with: NSRange(location: lastEnd, length: fullRange.location - lastEnd))
                    if duplicateNames.contains(name) {
                        if seenFirst.contains(name) {
                            rebuilt += "\(name) ="
                        } else {
                            seenFirst.insert(name)
                            rebuilt += "let \(name) ="
                        }
                    } else {
                        rebuilt += ns.substring(with: fullRange)
                    }
                    lastEnd = fullRange.location + fullRange.length
                }
                rebuilt += ns.substring(with: NSRange(location: lastEnd, length: ns.length - lastEnd))
                result += Array(rebuilt)
            case .block(let b):
                let inner = Array(b.dropFirst().dropLast())
                let processedInner = processDeclScope(inner)
                result.append("{")
                result += processedInner
                result.append("}")
            }
        }
        return result
    }

    public func transpileSwiftToJS(swift: String) -> String {
        var js = stripLineComments(swift)

        // Must run before everything else: converts `\(expr)` into `${expr}`
        // and switches the enclosing quotes to backticks, while leaving expr
        // itself as plain text so every later pass (argument-label stripping,
        // String(format:) conversion, self->this, etc.) still applies to it
        // exactly as it would anywhere else in the source.
        js = transpileStringInterpolation(text: js)

        // Must run before variable type annotations are stripped further
        // below — see rewriteDictionaryCountAccess for why a dictionary's
        // `.count` needs `Object.keys(...).length`, not the `.length` every
        // other `.count` gets.
        js = rewriteDictionaryCountAccess(js)

        // Erase `protocol Name { ... }` declarations and redistribute any
        // `extension Name { ... }` default method implementations onto
        // conforming types — see transpileProtocolDefaultImplementations
        // for why. Must run before the generic protocol-conformance-list
        // cleanup further below (step 1 in this pipeline), which strips the
        // `: SomeProtocol` conformance list this pass still needs intact to
        // know which types conform to which protocol, and before nested
        // type hoisting, so an injected default method is already sitting
        // in a conforming type's body by the time that runs.
        js = transpileProtocolDefaultImplementations(js)

        // Swift's optional-call syntax on a possibly-absent method
        // (`someObject.method?()`, e.g. calling an `@objc optional`
        // protocol requirement that a conforming type didn't implement) has
        // no direct JS equivalent as written — `?(` is not valid JS at all.
        // JS's own optional-chaining CALL syntax is `?.(`, not `?(` — the
        // dot is mandatory even when calling, unlike Swift's `?()`. A
        // literal `?()` substring (a `?` directly followed by `(` with zero
        // whitespace between them) doesn't occur in any other legitimate
        // Swift construct — a ternary's `?` always has whitespace around it
        // (`cond ? a : b`), and an optional TYPE marker (`Int?`) is always
        // followed by whitespace/`)`/`,`/newline, never directly by `(`.
        js = replaceRegex(in: js, pattern: "\\?\\(", template: "?.(")

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

        // Strip nested `CodingKeys` enums (Codable's JSON-key-remapping
        // metadata) before anything else tries to parse the body they sit
        // in — see extractAndStripCodingKeys for why leaving them in is a
        // hard JS syntax error. The extracted per-type rename maps are
        // attached to their JS classes at the very end of this pipeline,
        // once those classes actually exist.
        let (jsAfterCodingKeys, codingKeysMappings) = extractAndStripCodingKeys(js)
        js = jsAfterCodingKeys

        // Convert `switch`/`case` BEFORE `transpileEnumDeclarations` — a
        // `case .get(let key):` label is itself detected and consumed here
        // (see convertSwitchBody's enum-pattern handling), independent of
        // whether the `Op`-style factory class has been generated yet. This
        // order matters: `transpileEnumDeclarations`'s global leading-dot
        // rewrite (`.get(1)` -> `Op.get(1)`, for constructing enum values in
        // array/struct literals) has no way to distinguish that usage from
        // the SAME-LOOKING `.get(let key)` pattern-match shape in a case
        // label — both are just "a leading dot, a case name, parens" to a
        // blind text scan. Running switch conversion first consumes and
        // rewrites every case-label occurrence into `case 'get': {...}`
        // first, so by the time the enum pass's dot-rewrite runs, only the
        // genuine value-construction usages are left for it to match.
        js = transpileSwitchStatements(js)

        // Convert `enum` (with optional associated values) to a tagged-object
        // factory class, and rewrite `.CASENAME(...)` value construction
        // (e.g. inside an array/struct literal) to the explicit
        // `EnumName.CASENAME(...)` form.
        js = transpileEnumDeclarations(js)

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

        // 0b. Int.max/Int.min sentinels (common for "unset" accumulator init,
        // e.g. sliding-window/DP minimization) had no JS mapping at all —
        // `Int` is only ever mocked as a bare conversion function
        // (`function Int(v) { ... }`), so `Int.max` silently evaluated to
        // `undefined`, poisoning every later arithmetic/comparison with NaN.
        // Map to the safe-integer bounds (matches this codebase's own
        // Int64-exceeds-JS-safe-range serialization limit) — sufficient for
        // sentinel/comparison use; nothing here should ever *return* the
        // sentinel value itself un-substituted.
        js = js.replacingOccurrences(of: "Int.max", with: "Number.MAX_SAFE_INTEGER")
        js = js.replacingOccurrences(of: "Int.min", with: "Number.MIN_SAFE_INTEGER")

        // 0c. `someString.data(using: .utf8)!` (Swift's standard way to turn a
        // JSON string literal into Data before decoding it) has no JS
        // equivalent at all — JS strings aren't byte buffers, and the mocked
        // JSONDecoder().decode already accepts a plain string directly
        // (`if (typeof data === 'string') { JSON.parse(data) }`). Left alone,
        // argument-label stripping still reduces this to `.data(.utf8)`,
        // which is a hard SyntaxError (`.utf8` is a leading dot with no
        // receiver — `String.Encoding.utf8` has no JS mock at all). Since
        // the resulting Data is only ever immediately handed to decode(),
        // which is happy with the original string, the whole call (plus any
        // trailing force-unwrap) is simply removed, leaving the bare string.
        js = replaceRegex(in: js, pattern: "\\.data\\(using:\\s*\\.utf8\\)\\s*!?", template: "")

        // 1. Clean protocol conformances in class/struct/actor declarations
        js = replaceRegex(in: js, pattern: "\\b(class|struct|actor)\\s+(\\w+(?:<[^>]+>)?)\\s*:\\s*[^{]+", template: "$1 $2 ")

        // 2. Access modifiers stripper before declarations
        js = replaceRegex(in: js, pattern: "\\b(public|private|internal|fileprivate)\\s+(class|struct|actor)\\b", template: "$2")

        // 2a. Compound access-modifier-with-setter-scope syntax
        // (`private(set) var x`, also `public(set)`/`internal(set)`) — a
        // DIFFERENT token shape from the plain `private`/`public`/... the
        // regex right below strips; left unhandled, that regex's `\s+`
        // (requiring a plain keyword immediately followed by whitespace)
        // never matches `private(set)` at all, leaving it stuck as a literal
        // prefix in front of the property once later passes clean up
        // everything else around it (`private(set) auditLog = []`, invalid
        // JS class-field syntax). Must run BEFORE 2b below.
        js = replaceRegex(in: js, pattern: "\\b(?:public|private|internal|fileprivate)\\(set\\)\\s+", template: "")

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

        // Return-type/throws/async stripping ("Clean return types in
        // function signatures BEFORE class blocks and methods are
        // processed") used to be one blanket regex here — `\)\s*(async)?
        // \s*(?:throws|rethrows)?\s*->\s*[^{]+`, matching from the FIRST
        // `)` anywhere in the file through to the next `{` — which
        // silently assumed that `)` was always a function's own OUTER
        // closing paren. For `func f(x: @escaping (Int) -> Void) { ... }`,
        // the closure-typed parameter's own `)` (right after `Int`) is
        // ALSO immediately followed by `->`, so the regex matched THAT one
        // instead — consuming through to the function's real closing paren
        // as if it were part of the "return type" text and deleting it,
        // corrupting the signature (`func f(x: @escaping (Int)  {`, an
        // outer paren short) for every function with an escaping-closure
        // parameter. Preserving `async` (needed for JS's own async-function
        // marker; a later pass repositions it before `function`) while
        // fixing this requires knowing the TRUE closing paren — which is
        // exactly what the func/init loops below already compute via
        // `findMatchingParen` — so this is now folded into them instead of
        // being a separate, paren-depth-blind pass.

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
        // `components(separatedBy: ",")` split on EVERY comma, including one
        // nested inside a closure-typed parameter's own parameter list
        // (`completion: @escaping (Data?, Error?) -> Void)` has a comma
        // between `Data?` and `Error?` that has nothing to do with the
        // OUTER parameter list) — `splitTopLevelCommas` only splits on
        // commas at depth 0, leaving a closure type's internal comma alone.
        let cleanParamsFn: (String) -> String = { paramsStr in
            let params = self.splitTopLevelCommas(paramsStr)
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

        // Both loops below match only up through the opening `(` (never
        // `[^)]*`, which — like the params-capture bug this replaced —
        // stops at the FIRST `)` it sees, truncating early whenever a
        // closure-typed parameter's own type contains a `)` of its own),
        // then use `findMatchingParen` to locate the TRUE closing paren
        // regardless of any nested parens in between.
        if let funcRegex = try? NSRegularExpression(pattern: "\\bfunc\\s+(\\w+)\\s*\\(", options: []) {
            var searchStart = js.startIndex
            while searchStart < js.endIndex {
                let remainingRange = NSRange(searchStart..., in: js)
                guard let match = funcRegex.firstMatch(in: js, options: [], range: remainingRange),
                      let nameRange = Range(match.range(at: 1), in: js),
                      let matchRange = Range(match.range, in: js) else {
                    break
                }
                let funcName = String(js[nameRange])
                // matchRange ends right after the opening '(' (pattern ends in `\(`).
                let openParenIdx = js.index(before: matchRange.upperBound)
                guard let closeParenIdx = findMatchingParen(text: js, startIndex: openParenIdx) else {
                    searchStart = js.index(after: openParenIdx)
                    continue
                }

                let paramsStr = String(js[js.index(after: openParenIdx)..<closeParenIdx])
                let cleanedParams = cleanParamsFn(paramsStr)

                // Consume everything between the TRUE closing paren and the
                // method's body-opening `{` (async/throws/rethrows/return
                // type, in that order per Swift's own grammar), preserving
                // only `async` if present — matches the intermediate shape
                // (`function name(params) async `) the later async-
                // repositioning pass expects, without the paren-depth blind
                // spot the old separate regex pass had.
                let afterParenIdx = js.index(after: closeParenIdx)
                let bodyBraceIdx = js[afterParenIdx...].firstIndex(of: "{") ?? afterParenIdx
                let annotation = String(js[afterParenIdx..<bodyBraceIdx])
                let hasAsync = annotation.range(of: "\\basync\\b", options: .regularExpression) != nil

                let replacement = "function \(funcName)(\(cleanedParams))" + (hasAsync ? " async " : " ")
                js.replaceSubrange(matchRange.lowerBound..<bodyBraceIdx, with: replacement)
                searchStart = js.index(matchRange.lowerBound, offsetBy: replacement.count)
            }
        }

        if let initRegex = try? NSRegularExpression(pattern: "\\binit\\s*\\(", options: []) {
            var searchStart = js.startIndex
            while searchStart < js.endIndex {
                let remainingRange = NSRange(searchStart..., in: js)
                guard let match = initRegex.firstMatch(in: js, options: [], range: remainingRange),
                      let matchRange = Range(match.range, in: js) else {
                    break
                }
                let openParenIdx = js.index(before: matchRange.upperBound)
                guard let closeParenIdx = findMatchingParen(text: js, startIndex: openParenIdx) else {
                    searchStart = js.index(after: openParenIdx)
                    continue
                }

                let paramsStr = String(js[js.index(after: openParenIdx)..<closeParenIdx])
                let cleanedParams = cleanParamsFn(paramsStr)

                // Same reasoning as the func loop above — an init can have
                // `async`/`throws` (but never a return type) after its
                // parens: `init() async throws { ... }`.
                let afterParenIdx = js.index(after: closeParenIdx)
                let bodyBraceIdx = js[afterParenIdx...].firstIndex(of: "{") ?? afterParenIdx
                let annotation = String(js[afterParenIdx..<bodyBraceIdx])
                let hasAsync = annotation.range(of: "\\basync\\b", options: .regularExpression) != nil

                let replacement = "constructor(\(cleanedParams))" + (hasAsync ? " async " : " ")
                js.replaceSubrange(matchRange.lowerBound..<bodyBraceIdx, with: replacement)
                searchStart = js.index(matchRange.lowerBound, offsetBy: replacement.count)
            }
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

        // Every test harness's pass/fail check compares an actual value
        // against an expected one read off `tc` (`result == tc.expected`,
        // `actualGets == tc.expectedGets`, ...) — JS's `==`/`===` compares
        // arrays/objects by REFERENCE, always false for two structurally-
        // equal-but-distinct arrays, so any question whose return type is an
        // Array (not just the original hardcoded `result`/`tc.expected` pair)
        // needs the same JSON.stringify-based structural comparison. Safe to
        // apply generally to any `IDENT == tc.IDENT2` shape even when the
        // actual values are primitives (numbers/strings/bools) — two equal
        // primitives always stringify to identical text too.
        js = replaceRegex(in: js, pattern: "\\b(\\w+)\\s*==\\s*(tc\\.\\w+)\\b", template: "JSON.stringify($1) === JSON.stringify($2)")

        // String(format: "%.Nf", expr) — every existing question only ever
        // used this for cosmetic display text (a `Time: \(...)ms` interpolation
        // whose formatting doesn't affect pass/fail), so discarding the format
        // and keeping the bare expression was invisible. But the format IS
        // observable the moment a question's own return value or comparison
        // depends on the padded string (e.g. `execute() -> String { return
        // String(format: "%.2f", total) }` compared against a hardcoded
        // "14.50") — a bare number there fails a strict JS `===` against that
        // string outright. Real fixed-point formatting via `.toFixed(N)`,
        // matching Swift's %.Nf rounding for the non-negative values every
        // current question's numeric formatting is used for.
        // NOTE: the `([^)]+)` capture still can't see past a nested call's own
        // closing paren (`String(format: "%.2f", getTotalPrice())` mis-captures
        // at the first `)`), the same known limitation as every other
        // single-level-paren regex in this file — callers should assign the
        // expression to a local first if it isn't already argument-free.
        js = replaceRegex(in: js, pattern: "String\\s*\\(\\s*format\\s*:\\s*\"%\\.(\\d+)f\"\\s*,\\s*([^)]+)\\)", template: "Number($2).toFixed($1)")

        // Strip property wrapper UserDefault class definition
        let userDefaultClassPattern = "class\\s+UserDefault\\s*\\{[^{}]*(?:\\{[^{}]*(?:\\{[^{}]*\\}[^{}]*)*\\}[^{}]*)*\\}"
        js = replaceRegex(in: js, pattern: userDefaultClassPattern, template: "")

        // Strip Swift type casting as? / as! / as
        js = replaceRegex(in: js, pattern: "\\bas[?!]?\\s+[A-Za-z0-9_?\\[\\]<>:]+", template: "")

        // Implicit enums (.milliseconds(100) -> 100)
        js = replaceRegex(in: js, pattern: "\\.milliseconds\\((\\d+)\\)", template: "$1")
        js = replaceRegex(in: js, pattern: "\\.seconds\\((\\d+)\\)", template: "$1 * 1000")

        // Strip weak self / weak this and guard let self (MUST RUN BEFORE
        // general guard handling — a self-referential `guard let self = self
        // else { return }` isn't a real optional binding at all by the time
        // it reaches JS, it's a no-op unwrap of `this`, which can't be
        // `const`-declared as an identifier).
        js = replaceRegex(in: js, pattern: "\\[\\s*weak\\s+(?:self|this)\\s*\\]", template: "")
        js = replaceRegex(in: js, pattern: "guard\\s+let\\s+this\\s*=\\s*this\\s+else\\s*\\{\\s*return\\s*\\}", template: "")
        js = replaceRegex(in: js, pattern: "guard\\s+let\\s+self\\s*=\\s*self\\s+else\\s*\\{\\s*return\\s*\\}", template: "")

        // General guard handling (MUST RUN BEFORE trailing closures to avoid
        // conflicts with if/guard braces) — see transpileGuardStatements for
        // why this replaced three separate regexes that only supported an
        // else-block whose entire content was one literal `return ...`.
        js = transpileGuardStatements(js)

        // `async let name = expr` starts an async operation concurrently,
        // only actually awaited at first use — under this transpiler's
        // synchronous-by-default mocks (Task/DispatchQueue all execute
        // immediately) there is no real concurrency to defer anyway, so
        // eagerly awaiting right at the binding is an equivalent (if not
        // truly concurrent) substitute. Left unhandled, the blanket
        // `let`->`const` swap further below turns this into `async const
        // name = expr` — meaningless JS (the value is left as an
        // un-awaited, unresolved Promise wherever `name` is later used).
        js = replaceRegex(in: js, pattern: "\\basync\\s+let\\s+(\\w+)\\s*=\\s*([^\\n;]+)", template: "const $1 = await $2")

        // `let (a, b) = await (asyncLetA, asyncLetB)` — Swift's syntax for
        // awaiting several `async let` bindings together; see
        // transpileTupleAwaitDestructuring for why this needs its own
        // handling rather than any single regex substitution.
        js = transpileTupleAwaitDestructuring(js)

        // `let (a, b) = try await someCall()` — destructuring a SINGLE
        // tuple-returning async call's result (e.g. `URLSession.shared.data
        // (from: url)`, which returns `(Data, URLResponse)`), a completely
        // different shape from the "await several separately-awaited
        // expressions together" pattern just above (that one specifically
        // requires a parenthesized, comma-separated list immediately after
        // `await`; this one has a single call expression there instead).
        // Left unhandled, this survives as `const (data, response) =
        // await ...` — a hard SyntaxError, since JS tuple-like destructuring
        // only exists for arrays (`[a, b]`)/objects (`{a, b}`), never a
        // parenthesized name list. Converts to array destructuring, which
        // works as long as the mocked async call returns its result as a
        // plain 2-element array (matching Swift's positional `.0`/`.1`
        // tuple access) rather than an object.
        js = replaceRegex(in: js, pattern: "\\b(?:let|const)\\s*\\(([^)]+)\\)\\s*=\\s*(?:try\\s+)?await\\s+([^\\n;]+)", template: "const [$1] = await $2")

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

        // `if var val = optionalExpr { ... }` — a mutable-copy optional
        // binding (legal, if less common than `if let`; used when the
        // unwrapped value needs further local mutation, e.g. `if var val =
        // graph[key] { val.append(x); graph[key] = val }`). None of the
        // four `if let` regexes just above recognize the `var` keyword at
        // all, so this fell through untouched all the way to the generic
        // bare "if EXPR {" wrapper further below — which then wrapped the
        // literal text `var val = graph[key]` in parens rather than
        // unwrapping it, and the blanket `var`->`let` swap elsewhere in
        // this same pipeline corrupted it further into the nonsensical (and
        // syntactically invalid) `if (let val = ...)`. Mirrors the `if let`
        // versions exactly, except the JS binding becomes `let` rather than
        // `const` — matching Swift's own `var` (vs `let`) mutability intent
        // in case the unwrapped copy is later reassigned outright, not just
        // mutated in place.
        js = replaceRegex(in: js, pattern: "if\\s+([^,{]+?),\\s*var\\s+(\\w+)\\s*=\\s*([^,{]+?),\\s*([^{]+?)\\s*\\{", template: "let $2 = $3; if (($1) && $2 !== undefined && $2 !== null && ($4)) {")
        js = replaceRegex(in: js, pattern: "if\\s+([^,{]+?),\\s*var\\s+(\\w+)\\s*=\\s*([^{]+?)\\s*\\{", template: "let $2 = $3; if (($1) && $2 !== undefined && $2 !== null) {")
        js = replaceRegex(in: js, pattern: "if\\s+var\\s+(\\w+)\\s*=\\s*([^,{]+?),\\s*([^{]+?)\\s*\\{", template: "let $1 = $2; if ($1 !== undefined && $1 !== null && ($3)) {")
        js = replaceRegex(in: js, pattern: "if\\s+var\\s+(\\w+)\\s*=\\s*([^{]+)\\{", template: "let $1 = $2; if ($1 !== undefined && $1 !== null) {")
        // Allows a complete backtick-quoted segment within the condition —
        // same fix as transpileGuardStatements: a bare `if EXPR {` whose
        // EXPR contains string interpolation (already converted to a
        // `${...}` backtick template literal by this point in the
        // pipeline, e.g. `if vovelSet.contains("\(sArray[i])") {`) has a
        // literal `{`/`}` pair the plain `[^{]+` couldn't tell apart from
        // this if's own opening brace, so the match failed for the WHOLE
        // condition and left the raw, unparenthesized `if EXPR {` behind —
        // a hard SyntaxError once JS tries to parse `if` without a `(`.
        js = replaceRegex(in: js, pattern: "if\\s+([^({\\s](?:`[^`]*`|[^{])*)\\s*\\{", template: "if ($1) {")

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
        // Matches `while var x = expr` too (same reasoning as the `if var`/
        // `guard var` fixes nearby) — the JS output already needs a
        // reassignable binding either way (the loop reassigns `$1` in its
        // own condition every iteration), so `var`-vs-`let` in the Swift
        // source makes no difference to the generated JS here; only the
        // regex needed to actually recognize the `var` keyword at all.
        js = replaceRegex(in: js, pattern: "while\\s+(?:let|var)\\s+(\\w+)\\s*=\\s*([^,{]+?),\\s*([^{]+?)\\s*\\{", template: "var $1; while (($1 = $2) !== undefined && $1 !== null && ($3)) {")
        // Same, but without a trailing `, cond` — just `while let x = expr {`.
        js = replaceRegex(in: js, pattern: "while\\s+(?:let|var)\\s+(\\w+)\\s*=\\s*([^{]+?)\\s*\\{", template: "var $1; while (($1 = $2) !== undefined && $1 !== null) {")

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
        // Also allow `[`/`]` — a bound naming a MATRIX row/column count
        // (`matrix[0].count`, very common in any 2D-array question) has
        // exactly the same failure mode: `[` isn't in `[\w.]+` either, so
        // `for j in 0..<matrix[0].count {` previously left `[0].count {`
        // dangling right after the emitted `for(...)`, which a later pass
        // then misread as a subscript-plus-trailing-closure call.
        // Bounds also allow a PARENTHESIZED arithmetic expression
        // (`(newArray.count - 1)`, `(chars.count / 2)`) — not just a bare
        // dotted/subscript path. Previously `(`/`)`/arithmetic operators
        // weren't in the allowed set at all, so `for j in 1..<(arr.count -
        // 1) {` left the ENTIRE range expression unmatched (fell through
        // to the generic `for x in collection {` catch-all further below,
        // which just wraps the raw, still-Swift-syntax `1..<(arr.count -
        // 1)` text in a JS `for...of` — a hard SyntaxError, since `..<`
        // means nothing to JS). `{` is deliberately NOT in this set, so
        // the match still correctly stops at the loop body's opening
        // brace exactly as before, even though whitespace is now allowed.
        js = replaceRegex(in: js, pattern: "for\\s+(\\w+)\\s+in\\s+([\\w.\\[\\]()+\\-*/\\s]+)\\s*\\.\\.\\.\\s*([\\w.\\[\\]()+\\-*/\\s]+)", template: "for (var $1 = $2; $1 <= $3; $1++)")
        js = replaceRegex(in: js, pattern: "for\\s+(\\w+)\\s+in\\s+([\\w.\\[\\]()+\\-*/\\s]+)\\s*\\.\\.<\\s*([\\w.\\[\\]()+\\-*/\\s]+)", template: "for (var $1 = $2; $1 < $3; $1++)")

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

        // Same, for a CLASS method whose `function` keyword has already been
        // stripped by `stripFunctionKeywordAtTopLevel` (JS class-method
        // shorthand has no `function` keyword at all) — `recordAudit(entry)
        // async {` is invalid JS positioning; the `async` keyword must
        // appear BEFORE the method name (`async recordAudit(entry) {`), not
        // after its parameter list. Runs after the top-level regex above, so
        // it only ever sees what that one didn't already consume (a
        // top-level `function NAME(...) async {` no longer matches this
        // pattern once converted to `async function NAME(...) {`).
        js = replaceRegex(in: js, pattern: "\\b(\\w+)\\s*\\(([^)]*)\\)\\s*async\\s*\\{", template: "async $1($2) {")

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
        // assignment. Rewritten as a guarded assignment. The receiver group
        // allows a dotted path with any number of segments (`(?:\w+\.)*\w+`),
        // not just a single bare identifier — `head.next?.prev = node` (this
        // codebase's own `LRUCache.insertAtFront`, after `this.`-prefixing
        // has already turned it into `this.head.next?.prev = node`) needs
        // its FULL receiver `this.head.next` captured and reused as the
        // guard/assignment target; a single-identifier capture only grabs
        // the last segment (`next`), leaving everything before it (`this.
        // head.`) stuck as a dangling, syntactically invalid prefix in front
        // of the synthesized `if (...) {...}`.
        js = replaceRegex(in: js, pattern: "((?:\\w+\\.)*\\w+)\\?\\.(\\w+)\\s*=\\s*([^\\n;]+)", template: "if ($1) { $1.$2 = $3; }")

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

        // Array.remove(at: i) -> .splice(i, 1) — MUST match the literal
        // `at:` label BEFORE it's stripped by the call-site-label whitelist
        // right below, since that's the only textual signal distinguishing
        // Swift's `Array.remove(at:)` from an arbitrary same-named custom
        // method called positionally (e.g. this codebase's own
        // `LRUCache.remove(_ node: Node)`, called as `remove(node)`) — both
        // look identically like `.remove(x)` once any argument label is
        // gone. A blind `\.remove\(...\)` -> `.splice($1, 1)` regex run AFTER
        // the whitelist strip previously mangled that unrelated method's own
        // call sites too (`this.remove(node)` -> `this.splice(node, 1)`,
        // `TypeError: this.splice is not a function`).
        js = replaceRegex(in: js, pattern: "\\.remove\\(\\s*at\\s*:\\s*([^)]+)\\)", template: ".splice($1, 1)")

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

        // Must run BEFORE the blanket Array `.append(x) -> .push(x)` rule
        // right below, so a detected String variable's `.append` calls are
        // already rewritten to `+=` and no longer match that rule's regex.
        js = rewriteStringAppendCalls(js)

        // .append(x) -> .push(x) and .removeLast() -> .pop() — Array methods
        // with no JS equivalent name (JS arrays use push/pop for the same
        // stack-style operations Swift spells append/removeLast).
        js = replaceRegex(in: js, pattern: "\\.append\\(", template: ".push(")
        js = replaceRegex(in: js, pattern: "\\.removeLast\\(\\)", template: ".pop()")

        // Dictionary.removeValue(forKey: k) -> delete obj[k] — `forKey:` is
        // already stripped to a bare argument by the whitelist above, so by
        // this point it reads `.removeValue(k)`; JS objects have no method
        // equivalent, only the `delete` operator, which needs the receiver
        // and key rewritten into `delete obj[k]` rather than a chained call.
        // The receiver allows a dotted path with any number of segments
        // (same reasoning as the optional-chaining-assignment fix above) —
        // `this.nodes.removeValue(...)` (this codebase's own
        // `LRUCache.put`, after `this.`-prefixing) needs its FULL receiver
        // `this.nodes` captured, or `this.` is left stuck as a dangling
        // prefix in front of the `delete` keyword.
        js = replaceRegex(in: js, pattern: "((?:\\w+\\.)*\\w+)\\.removeValue\\(([^)]+)\\)", template: "delete $1[$2]")

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

        // `(LOWER..<UPPER).contains(x)` / `(LOWER...UPPER).contains(x)` — a
        // Range literal's `.contains` is a bounds check, not a membership
        // test on a collection; it has nothing to do with the Set/Array
        // `.contains` the blanket rule right below handles, and JS has no
        // Range type to call `.has`/`.contains` on at all regardless. Common
        // idiom for validating e.g. an HTTP status code. MUST run before
        // that blanket rule, which would otherwise blindly rewrite this to
        // the equally-invalid `(200..<300).has(x)` — this transpiler has no
        // type information, so a bare `.contains(` is indistinguishable
        // from the Set case to it without checking for a Range literal
        // receiver first, specifically.
        js = replaceRegex(in: js, pattern: "\\(\\s*([^()]+?)\\s*\\.\\.<\\s*([^()]+?)\\s*\\)\\.contains\\(([^()]+)\\)", template: "($3 >= $1 && $3 < $2)")
        js = replaceRegex(in: js, pattern: "\\(\\s*([^()]+?)\\s*\\.\\.\\.\\s*([^()]+?)\\s*\\)\\.contains\\(([^()]+)\\)", template: "($3 >= $1 && $3 <= $2)")

        // Set.contains(x) -> Set.has(x) — JS Sets use `has`, not `contains`.
        js = replaceRegex(in: js, pattern: "\\.contains\\(", template: ".has(")

        // Set.insert(x) -> Set.add(x) — JS Sets use `add`, not `insert`, and
        // there was no mapping for this at all (only `.contains`/`.has` had
        // one). Restricted to a SINGLE, paren/comma-free argument so this
        // never touches `Array.insert(x, at: i)` (a completely different,
        // positional-insert method) — that call always has a second
        // argument, with or without the `at:` label already stripped by
        // this point in the pipeline, so requiring no top-level comma here
        // safely excludes it.
        js = replaceRegex(in: js, pattern: "\\.insert\\(([^,()]+)\\)", template: ".add($1)")

        // .dropFirst() / .dropFirst(n) -> .slice(1) / .slice(n) — Array
        // method with no JS equivalent name (JS has no `.dropFirst`; `.slice`
        // with a single start index does the same "everything after index N"
        // slice, defaulting to dropping just the first element).
        js = replaceRegex(in: js, pattern: "\\.dropFirst\\(\\s*\\)", template: ".slice(1)")
        js = replaceRegex(in: js, pattern: "\\.dropFirst\\(([^)]+)\\)", template: ".slice($1)")

        // .max() / .min() (no-argument overloads) — Array method returning
        // the largest/smallest element (an Optional, nil for an empty
        // array). JS has no native Array.prototype.max()/min() at all, so
        // this was a hard ReferenceError-equivalent (`TypeError: ...max is
        // not a function`) for every question using it. `Math.max(...arr)`/
        // `Math.min(...arr)` is the direct equivalent for a non-empty array
        // of numbers, spreading it as individual arguments. Only handles a
        // simple identifier/property-access receiver directly before the
        // call (`arr.max()`, `self.items.max()`) — not an arbitrary
        // expression receiver like a chained `.filter{...}.max()` — and
        // does not replicate Swift's nil-for-empty-array behavior
        // (`Math.max(...[])` is `-Infinity`, not `undefined`/`null`),
        // which only matters for code that specifically branches on an
        // empty-array call site.
        js = replaceRegex(in: js, pattern: "([\\w.]+)\\.max\\(\\)", template: "Math.max(...$1)")
        js = replaceRegex(in: js, pattern: "([\\w.]+)\\.min\\(\\)", template: "Math.min(...$1)")

        // .removeFirst() -> .shift() — Swift's "remove and return the first
        // element" (the standard way to pop from the front of an array-as-
        // queue, e.g. BFS/topological-sort traversal) has no `.removeFirst`
        // in JS at all; `.shift()` is the exact same operation under a
        // different name. No mapping for this existed previously.
        js = replaceRegex(in: js, pattern: "\\.removeFirst\\(\\s*\\)", template: ".shift()")

        // .joined() / .joined(separator: "x") -> .join() / .join("x") — same
        // method under a different name (`separator:` is already stripped to
        // a bare argument by the general call-site label stripper by this
        // point, or by the whitelist regex above if it ran first).
        js = replaceRegex(in: js, pattern: "\\.joined\\(", template: ".join(")

        // .hasPrefix(x) / .hasSuffix(x) -> .startsWith(x) / .endsWith(x) —
        // Swift String methods with no JS equivalent under the same name.
        // Had no conversion path at all before (confirmed: every other
        // `hasPrefix`/`hasSuffix` reference in this file is the transpiler's
        // OWN host-side Swift code, not a rule converting target/user code),
        // so any solution calling either — a very ordinary string-parsing
        // idiom — left the literal Swift method name in the emitted JS,
        // a hard "is not a function" TypeError at runtime.
        js = replaceRegex(in: js, pattern: "\\.hasPrefix\\(", template: ".startsWith(")
        js = replaceRegex(in: js, pattern: "\\.hasSuffix\\(", template: ".endsWith(")

        // .lowercased() / .uppercased() -> .toLowerCase() / .toUpperCase()
        // — had no conversion path at all (confirmed: no reference to
        // either name anywhere else in this file), despite being an
        // extremely ordinary String operation.
        js = replaceRegex(in: js, pattern: "\\.lowercased\\(\\s*\\)", template: ".toLowerCase()")
        js = replaceRegex(in: js, pattern: "\\.uppercased\\(\\s*\\)", template: ".toUpperCase()")

        // .replacingOccurrences(of: X, with: Y) -> .split(X).join(Y) — by
        // this point the general call-site label stripper has already
        // reduced this to positional args, .replacingOccurrences(X, Y), but
        // nothing renamed the METHOD ITSELF: JS strings have no
        // `.replacingOccurrences` at all. `.split(X).join(Y)` is the
        // classic (and universally-supported, unlike the newer
        // `.replaceAll`) JS idiom for "replace every occurrence", matching
        // Swift's own all-occurrences (not just-the-first) semantics
        // exactly. Had no conversion path at all before, despite being an
        // extremely ordinary string-parsing idiom.
        js = replaceRegex(in: js, pattern: "\\.replacingOccurrences\\(([^,]+),\\s*([^)]+)\\)", template: ".split($1).join($2)")

        // .components(separatedBy: "x") -> .split("x") — Swift's String
        // splitting method; JS strings have no `.components`, only `.split`.
        // `separatedBy` isn't in the call-site-label whitelist (it's a
        // String-specific label, unlike the Combine/URLSession-oriented names
        // already there), so it needs its own explicit conversion rather
        // than falling through to the generic label stripper.
        js = replaceRegex(in: js, pattern: "\\.components\\s*\\(\\s*separatedBy\\s*:\\s*([^)]+)\\)", template: ".split($1)")

        // (expr).rounded() -> Math.round(expr) — Swift's Double.rounded()
        // method has no JS receiver-style equivalent; Math.round is a
        // top-level function taking the value as an argument instead.
        // Same `$`-omission gap as the `.sorted()` fix above — a closure
        // shorthand receiver (`$0.rounded()`) would otherwise leave a
        // dangling `$` prefix ahead of `Math.round(0)`.
        js = replaceRegex(in: js, pattern: "([\\w.$]+|\\([^)\\n]+\\))\\.rounded\\(\\)", template: "Math.round($1)")

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
        // Receiver class includes `$` — `\w` alone excludes it, so a closure
        // shorthand receiver (`$0.sorted()`, e.g. inside `.map { $0.sorted()
        // ... }`) previously matched only the bare "0", leaving the `$`
        // behind unconsumed; spliced against the replacement's own leading
        // "Array", that silently produced `$Array.from(0).sort()` — a
        // ReferenceError at runtime, not a compile-time symptom, since `$`
        // is itself a legal (if unusual) JS identifier character.
        js = replaceRegex(in: js, pattern: "([\\w.$]+)\\.sorted\\s*\\(\\s*\\)", template: "Array.from($1).sort()")
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
        // A word-boundary-aware regex, not a blind substring replace — the
        // previous `replacingOccurrences(of: ".count", with: ".length")`
        // matched ".count" as a literal substring ANYWHERE, including as a
        // prefix of a longer, unrelated identifier (e.g. a user-defined
        // method called `countAgesAtLeast50`), silently corrupting call
        // sites like `Solution().countAgesAtLeast50(...)` into
        // `Solution().lengthAgesAtLeast50(...)` — a hard "is not a
        // function" TypeError at runtime, while the function's own
        // declaration (never touched by this same blind replace, since it
        // has no leading `.`) stayed correctly named, desyncing the two.
        js = replaceRegex(in: js, pattern: "\\.count\\b", template: ".length")
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

        // Character.isLetter / .isNumber / .isUppercase / .isLowercase /
        // .isWhitespace — had no conversion path at all (every other
        // `isLetter`/`isNumber`/... reference anywhere in this file is the
        // TRANSPILER'S OWN host-side Swift code scanning identifiers, not a
        // rule converting target/user code), so a solution testing
        // character classes one at a time character-by-character — an
        // extremely ordinary string-parsing idiom (word-splitting,
        // tokenizing, validating input) — silently evaluated every check to
        // `undefined` (falsy), never throwing but always taking the "false"
        // branch regardless of the real character.
        let receiverPattern = "([\\w]+(?:\\.[\\w]+|\\[[^\\]]+\\])*)"
        js = replaceRegex(in: js, pattern: "\(receiverPattern)\\.isLetter\\b", template: "/[a-zA-Z]/.test($1)")
        js = replaceRegex(in: js, pattern: "\(receiverPattern)\\.isNumber\\b", template: "/[0-9]/.test($1)")
        js = replaceRegex(in: js, pattern: "\(receiverPattern)\\.isUppercase\\b", template: "/[A-Z]/.test($1)")
        js = replaceRegex(in: js, pattern: "\(receiverPattern)\\.isLowercase\\b", template: "/[a-z]/.test($1)")
        js = replaceRegex(in: js, pattern: "\(receiverPattern)\\.isWhitespace\\b", template: "/\\s/.test($1)")

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
        // `subscriptExpr!` — force-unwrapping a subscript/dictionary access
        // (`graph[first]!`, `degreeMap[neighbour]!`) has no representation
        // in any of the three rules above: all three require a bare
        // identifier (`\w+`) immediately before the `!`, but a subscript
        // ends in `]`, not a word character. Left unhandled, the literal
        // `!` survives into the JS output wherever it's NOT immediately
        // followed by one of the specific characters the second rule
        // whitelists (a `for (const x of dict[k]!)` loop header, or `dict[k]!
        // -= 1`, both end up with a stray `!` that isn't valid postfix JS
        // syntax anywhere). Strips unconditionally after `]` except before
        // `=` (so `!= `/`!==` immediately after a subscript, e.g. `arr[i]!=
        // arr[j]`, is left alone — that `!` is the not-equal operator, not
        // a force-unwrap).
        js = replaceRegex(in: js, pattern: "\\]!(?!=)", template: "]")

        // Add an implicit `return` to a named function/method whose ENTIRE
        // body is a single bare expression, matching Swift's own implicit-
        // return rule for such bodies — see wrapImplicitReturnForNamedBodies
        // for why this only applies to closures before now.
        js = wrapImplicitReturnForNamedBodies(js)

        // Run last, once every other pass has settled on final `const`/`let`
        // tokens: see rescopeDuplicateDeclarations for why a same-named
        // binding can legitimately appear twice in what is really one JS
        // scope (most commonly an `if let x = ...` early-exit followed later
        // by a plain `let x = ...` in the same function).
        js = String(rescopeDuplicateDeclarations(js))

        // Attach each CodingKeys rename map (extracted near the start of
        // this pipeline, before `struct`/`class` even became a JS `class`)
        // to its now-real JS class, for the JSONDecoder mock to consult.
        // MUST be inserted immediately after the class's OWN closing brace,
        // not simply appended at the very end of the whole script — a
        // decode() call almost always appears earlier in the same file than
        // the last line, and an end-of-file assignment would still be
        // `undefined` at that point (this was caught by actually running a
        // decode call through the JS engine, not just reading the diff:
        // stargazersCount printed as `undefined` even though the map was
        // correctly built, because it was attached only after the loop that
        // printed it had already run).
        for (typeName, map) in codingKeysMappings {
            guard let classRegex = try? NSRegularExpression(pattern: "\\bclass\\s+\(NSRegularExpression.escapedPattern(for: typeName))\\b[^{]*\\{") else { continue }
            let nsJs = js as NSString
            guard let classMatch = classRegex.firstMatch(in: js, options: [], range: NSRange(location: 0, length: nsJs.length)) else { continue }
            let jsChars = Array(js)
            let openBraceOffset = classMatch.range.location + classMatch.range.length - 1
            guard let closeBraceOffset = findMatchingBraceInChars(jsChars, openIdx: openBraceOffset) else { continue }

            let entries = map.map { "\"\($0.key)\": \"\($0.value)\"" }.joined(separator: ", ")
            let insertion = "\ntry { \(typeName).__codingKeysMap = {\(entries)}; } catch (e) {}"
            var mutable = jsChars
            mutable.insert(contentsOf: insertion, at: closeBraceOffset + 1)
            js = String(mutable)
        }

        return js
    }
}

