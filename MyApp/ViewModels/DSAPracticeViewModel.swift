import Foundation
import Combine

@MainActor
public class DSAPracticeViewModel: ObservableObject {
    @Published public var currentQuestion: Question?
    @Published public var code: String = ""
    @Published public var isRunning = false
    @Published public var consoleOutput = "Run code to execute test suite."
    @Published public var testcaseResults: [TestCaseResult] = []
    @Published public var selectedTestCaseIndex = 0
    @Published public var compilerError: String? = nil
    
    private let codeRunner: CodeRunnerProtocol
    public var onSuccess: (() -> Void)?
    
    public init(codeRunner: CodeRunnerProtocol? = nil) {
        self.codeRunner = codeRunner ?? CodeRunnerService()
    }
    
    public func loadQuestion(_ question: Question, draft: String? = nil) {
        self.currentQuestion = question
        let cleanDraft = draft?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleanSolution = question.solutionCode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let missingReturn = question.templateCode.contains("return ") && !cleanDraft.contains("return ")
        
        if cleanDraft.isEmpty || cleanDraft == cleanSolution || missingReturn {
            self.code = question.templateCode
        } else {
            self.code = draft ?? question.templateCode
        }
        
        self.testcaseResults = []
        self.consoleOutput = "Loaded \(question.title). Ready to edit."
        self.compilerError = nil
    }
    
    public func resetCode() {
        guard let question = currentQuestion else { return }
        self.code = question.templateCode
        self.testcaseResults = []
        self.consoleOutput = "Code reset to starter template."
        self.compilerError = nil
    }
    
    public func insertSolutionToEditor() {
        guard let question = currentQuestion else { return }
        self.code = question.solutionCode
        self.consoleOutput = "Official reference solution inserted into editor."
    }
    
    public func runCode() async {
        guard let question = currentQuestion else { return }
        self.isRunning = true
        self.consoleOutput = "Compiling and running Swift tests...\n"
        self.compilerError = nil
        self.testcaseResults = []
        
        LoggerService.shared.log("Initiating code run for question: \(question.title)", level: .info, category: .codeRunner)
        
        let result = await codeRunner.runSwiftCode(code: code, appendHarness: question.testHarness ?? "")
        
        self.isRunning = false
        if result.exitCode == -2 {
            self.consoleOutput = "Native Swift execution not supported. Running in sandbox simulation mode...\n"
            LoggerService.shared.log("Native execution unavailable for \(question.title). Running JS sandbox...", level: .warning, category: .codeRunner)
            self.runJSFallback()
        } else if result.exitCode != 0 {
            self.compilerError = result.stderr.isEmpty ? result.stdout : result.stderr
            self.consoleOutput = "Compilation Failed.\n\n" + (self.compilerError ?? "")
            LoggerService.shared.log("Compilation/Execution failed for \(question.title):\n--- ERROR OUTPUT ---\n\(self.compilerError ?? "")", level: .error, category: .codeRunner)
        } else {
            self.consoleOutput = result.stdout
            LoggerService.shared.log("Execution succeeded for \(question.title):\n--- EXECUTION OUTPUT ---\n\(result.stdout)", level: .success, category: .codeRunner)
            if question.category == "swiftPractice" {
                if !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.onSuccess?()
                }
            } else {
                self.parseDSAResults(stdout: result.stdout)
            }
        }
    }
    
    private func runJSFallback() {
        guard let question = currentQuestion else { return }
        let transpiled = codeRunner.transpileSwiftToJS(swift: code)
        
        let runnerScript: String
        switch question.id {
        case "two_sum":
            runnerScript = """
            \(transpiled)
            function runTests() {
                const solution = new Solution();
                const testCases = [
                    { nums: [2, 7, 11, 15], target: 9, expected: [0, 1], name: "Example 1 ([2,7,11,15], target 9)" },
                    { nums: [3, 2, 4], target: 6, expected: [1, 2], name: "Example 2 ([3,2,4], target 6)" },
                    { nums: [3, 3], target: 6, expected: [0, 1], name: "Example 3 ([3,3], target 6)" }
                ];
                let passedCount = 0; const results = [];
                for (let i = 0; i < testCases.length; i++) {
                    const tc = testCases[i]; const start = Date.now();
                    try {
                        const res = solution.twoSum(tc.nums, tc.target);
                        const passed = JSON.stringify(res) === JSON.stringify(tc.expected);
                        if (passed) passedCount++;
                        results.push(`CASE ${i} | ${passed ? 'PASS' : 'FAIL'} | Name: ${tc.name} | Output: [${res}] | Expected: [${tc.expected}] | Time: ${Date.now() - start}ms`);
                    } catch (e) { results.push(`CASE ${i} | FAIL | Name: ${tc.name} | Error: ${e.message}`); }
                }
                return `---DSA_TEST_RESULTS_START---\\n` + results.join('\\n') + `\\nSUMMARY | ${passedCount}/${testCases.length} PASSED\\n---DSA_TEST_RESULTS_END---`;
            }
            runTests();
            """
        case "valid_parentheses":
            runnerScript = """
            \(transpiled)
            function runTests() {
                const solution = new Solution();
                const testCases = [
                    { s: "()", expected: true, name: "Example 1 (\\"()\\")" },
                    { s: "()[]{}", expected: true, name: "Example 2 (\\"()[]{}\\")" },
                    { s: "(]", expected: false, name: "Example 3 (\\"(]\\")" },
                    { s: "([)]", expected: false, name: "Example 4 (\\"([)]\\")" },
                    { s: "{[]}", expected: true, name: "Example 5 (\\"{[]}\\")" }
                ];
                let passedCount = 0; const results = [];
                for (let i = 0; i < testCases.length; i++) {
                    const tc = testCases[i]; const start = Date.now();
                    try {
                        const res = solution.isValid(tc.s);
                        const passed = res === tc.expected;
                        if (passed) passedCount++;
                        results.push(`CASE ${i} | ${passed ? 'PASS' : 'FAIL'} | Name: ${tc.name} | Output: ${res} | Expected: ${tc.expected} | Time: ${Date.now() - start}ms`);
                    } catch (e) { results.push(`CASE ${i} | FAIL | Name: ${tc.name} | Error: ${e.message}`); }
                }
                return `---DSA_TEST_RESULTS_START---\\n` + results.join('\\n') + `\\nSUMMARY | ${passedCount}/${testCases.length} PASSED\\n---DSA_TEST_RESULTS_END---`;
            }
            runTests();
            """
        case "climb_stairs":
            runnerScript = """
            \(transpiled)
            function runTests() {
                const solution = new Solution();
                const testCases = [
                    { n: 2, expected: 2, name: "Example 1 (n = 2)" },
                    { n: 3, expected: 3, name: "Example 2 (n = 3)" },
                    { n: 5, expected: 8, name: "n = 5" },
                    { n: 1, expected: 1, name: "Edge Case (n = 1)" },
                    { n: 10, expected: 89, name: "n = 10" }
                ];
                let passedCount = 0; const results = [];
                for (let i = 0; i < testCases.length; i++) {
                    const tc = testCases[i]; const start = Date.now();
                    try {
                        const res = solution.climbStairs(tc.n);
                        const passed = res === tc.expected;
                        if (passed) passedCount++;
                        results.push(`CASE ${i} | ${passed ? 'PASS' : 'FAIL'} | Name: ${tc.name} | Output: ${res} | Expected: ${tc.expected} | Time: ${Date.now() - start}ms`);
                    } catch (e) { results.push(`CASE ${i} | FAIL | Name: ${tc.name} | Error: ${e.message}`); }
                }
                return `---DSA_TEST_RESULTS_START---\\n` + results.join('\\n') + `\\nSUMMARY | ${passedCount}/${testCases.length} PASSED\\n---DSA_TEST_RESULTS_END---`;
            }
            runTests();
            """
        case "rod_cutting":
            runnerScript = """
            \(transpiled)
            function runTests() {
                const solution = new Solution();
                const testCases = [
                    { price: [0, 1, 5, 8, 9, 10, 17, 17, 20], expected: 22, name: "Example 1 (Cut into lengths 2 & 6 -> 5+17=22)" },
                    { price: [0, 3, 5, 8, 9, 10, 17, 17, 20], expected: 24, name: "Example 2 (8 cuts of length 1 -> 8*3=24)" },
                    { price: [0, 3], expected: 3, name: "Example 3 (Single length 1 rod)" },
                    { price: [0, 1, 1, 1, 100], expected: 100, name: "Edge Case 1 (Single full length piece optimal)" },
                    { price: [0, 0, 0, 0], expected: 0, name: "Edge Case 2 (All zero prices)" },
                    { price: [0], expected: 0, name: "Edge Case 3 (Zero length rod)" },
                    { price: [0, 2, 5, 9, 10, 15, 17, 20, 24, 30], expected: 30, name: "Normal Case (Length 9 rod)" }
                ];
                let passedCount = 0; const results = [];
                for (let i = 0; i < testCases.length; i++) {
                    const tc = testCases[i]; const start = Date.now();
                    try {
                        const res = solution.cutRod(tc.price);
                        const passed = res === tc.expected;
                        if (passed) passedCount++;
                        results.push(`CASE ${i} | ${passed ? 'PASS' : 'FAIL'} | Name: ${tc.name} | Output: ${res} | Expected: ${tc.expected} | Time: ${Date.now() - start}ms`);
                    } catch (e) { results.push(`CASE ${i} | FAIL | Name: ${tc.name} | Error: ${e.message}`); }
                }
                return `---DSA_TEST_RESULTS_START---\\n` + results.join('\\n') + `\\nSUMMARY | ${passedCount}/${testCases.length} PASSED\\n---DSA_TEST_RESULTS_END---`;
            }
            runTests();
            """
        default:
            // Maximal Square & default fallback
            runnerScript = """
            \(transpiled)
            function runTests() {
                const solution = new Solution();
                const testCases = [
                    { matrix: [["1","0","1","0","0"],["1","0","1","1","1"],["1","1","1","1","1"],["1","0","0","1","0"]], expected: 4, name: "Example 1 (Normal matrix)" },
                    { matrix: [["0","1"],["1","0"]], expected: 1, name: "Example 2 (2x2 matrix)" },
                    { matrix: [["0"]], expected: 0, name: "Example 3 (Single cell 0)" },
                    { matrix: [], expected: 0, name: "Edge Case 1 (Empty matrix)" },
                    { matrix: [["1", "1", "1"]], expected: 1, name: "Edge Case 2 (1x3 all ones)" },
                    { matrix: [["0","0"],["0","0"]], expected: 0, name: "Edge Case 3 (2x2 all zeros)" },
                    { matrix: [["1","1","1"],["1","1","1"],["1","1","1"]], expected: 9, name: "Normal Case (3x3 all ones)" }
                ];
                let passedCount = 0; const results = [];
                for (let i = 0; i < testCases.length; i++) {
                    const tc = testCases[i]; const start = Date.now();
                    try {
                        const res = solution.maximalSquare(tc.matrix);
                        const passed = res === tc.expected;
                        if (passed) passedCount++;
                        results.push(`CASE ${i} | ${passed ? 'PASS' : 'FAIL'} | Name: ${tc.name} | Output: ${res} | Expected: ${tc.expected} | Time: ${Date.now() - start}ms`);
                    } catch (e) { results.push(`CASE ${i} | FAIL | Name: ${tc.name} | Error: ${e.message}`); }
                }
                return `---DSA_TEST_RESULTS_START---\\n` + results.join('\\n') + `\\nSUMMARY | ${passedCount}/${testCases.length} PASSED\\n---DSA_TEST_RESULTS_END---`;
            }
            runTests();
            """
        }
        
        let result = codeRunner.runJSCode(code: runnerScript)
        self.consoleOutput += "\n" + result
        LoggerService.shared.log("JS Sandbox execution output for \(question.title):\n--- EXECUTION OUTPUT ---\n\(result)", level: .info, category: .codeRunner)
        self.parseDSAResults(stdout: result)
    }
    
    private func parseDSAResults(stdout: String) {
        var parsedResults: [TestCaseResult] = []
        
        let lines = stdout.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("CASE ") {
                let parts = line.components(separatedBy: " | ")
                guard parts.count >= 2 else { continue }
                
                let caseIndexStr = parts[0].replacingOccurrences(of: "CASE ", with: "")
                let caseIndex = Int(caseIndexStr) ?? 0
                let isPass = parts[1] == "PASS"
                
                var name = ""
                var output = ""
                var expected = ""
                var time = ""
                var errorMsg: String? = nil
                
                for part in parts.dropFirst(2) {
                    if part.hasPrefix("Name: ") {
                        name = part.replacingOccurrences(of: "Name: ", with: "")
                    } else if part.hasPrefix("Output: ") {
                        output = part.replacingOccurrences(of: "Output: ", with: "")
                    } else if part.hasPrefix("Expected: ") {
                        expected = part.replacingOccurrences(of: "Expected: ", with: "")
                    } else if part.hasPrefix("Time: ") {
                        time = part.replacingOccurrences(of: "Time: ", with: "")
                    } else if part.hasPrefix("Error: ") {
                        errorMsg = part.replacingOccurrences(of: "Error: ", with: "")
                    }
                }
                
                parsedResults.append(TestCaseResult(
                    index: caseIndex,
                    isPass: isPass,
                    name: name,
                    output: output,
                    expected: expected,
                    time: time,
                    error: errorMsg
                ))
            }
        }
        
        self.testcaseResults = parsedResults
        if !parsedResults.isEmpty {
            self.selectedTestCaseIndex = 0
            let passCount = parsedResults.filter { $0.isPass }.count
            let allPassed = passCount == parsedResults.count
            LoggerService.shared.log("Test suite summary for \(currentQuestion?.title ?? "Question"): \(passCount)/\(parsedResults.count) PASSED", level: allPassed ? .success : .warning, category: .codeRunner)
            if allPassed {
                self.onSuccess?()
            }
        }
    }
}
