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
        let cleanDraft = draft?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSolution = question.solutionCode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanDraft == cleanSolution {
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
        self.consoleOutput = "Code reset to template."
        self.compilerError = nil
    }
    
    public func loadSolution() {
        guard let question = currentQuestion else { return }
        self.code = question.solutionCode
        self.testcaseResults = []
        self.consoleOutput = "Working solution loaded."
        self.compilerError = nil
    }
    
    public func runCode() async {
        guard let question = currentQuestion else { return }
        self.isRunning = true
        self.consoleOutput = "Compiling and running Swift tests...\n"
        self.compilerError = nil
        self.testcaseResults = []
        
        let result = await codeRunner.runSwiftCode(code: code, appendHarness: question.testHarness ?? "")
        
        self.isRunning = false
        if result.exitCode == -2 {
            self.consoleOutput = "Native Swift execution not supported. Running in sandbox simulation mode...\n"
            self.runJSFallback()
        } else if result.exitCode != 0 {
            self.compilerError = result.stderr.isEmpty ? result.stdout : result.stderr
            self.consoleOutput = "Compilation Failed.\n\n" + (self.compilerError ?? "")
        } else {
            self.consoleOutput = result.stdout
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
        if question.id == "climb_stairs" {
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
                
                let passedCount = 0;
                const results = [];
                for (let i = 0; i < testCases.length; i++) {
                    const tc = testCases[i];
                    const start = Date.now();
                    let result;
                    try {
                        if (typeof solution.climbStairs !== 'function') {
                            throw new Error("Method 'climbStairs' not found on Solution class.");
                        }
                        result = solution.climbStairs(tc.n);
                        const duration = Date.now() - start;
                        const passed = result === tc.expected;
                        if (passed) passedCount++;
                        results.push(`CASE ${i} | ${passed ? 'PASS' : 'FAIL'} | Name: ${tc.name} | Output: ${result} | Expected: ${tc.expected} | Time: ${duration}ms`);
                    } catch (e) {
                        results.push(`CASE ${i} | FAIL | Name: ${tc.name} | Error: ${e.message}`);
                    }
                }
                return `---DSA_TEST_RESULTS_START---\\n` + results.join('\\n') + `\\nSUMMARY | ${passedCount}/${testCases.length} PASSED\\n---DSA_TEST_RESULTS_END---`;
            }
            runTests();
            """
        } else {
            // Default: Maximal Square fallback
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
                
                let passedCount = 0;
                const results = [];
                
                for (let i = 0; i < testCases.length; i++) {
                    const tc = testCases[i];
                    const start = Date.now();
                    let result;
                    try {
                        if (typeof solution.maximalSquare !== 'function') {
                            throw new Error("Method 'maximalSquare' not found on Solution class.");
                        }
                        result = solution.maximalSquare(tc.matrix);
                        const duration = Date.now() - start;
                        const passed = result === tc.expected;
                        if (passed) passedCount++;
                        results.push(`CASE ${i} | ${passed ? 'PASS' : 'FAIL'} | Name: ${tc.name} | Output: ${result} | Expected: ${tc.expected} | Time: ${duration}ms`);
                    } catch (e) {
                        results.push(`CASE ${i} | FAIL | Name: ${tc.name} | Error: ${e.message}`);
                    }
                }
                
                return `---DSA_TEST_RESULTS_START---\\n` + results.join('\\n') + `\\nSUMMARY | ${passedCount}/${testCases.length} PASSED\\n---DSA_TEST_RESULTS_END---`;
            }
            runTests();
            """
        }
        
        let result = codeRunner.runJSCode(code: runnerScript)
        self.consoleOutput += "\n" + result
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
            let allPassed = parsedResults.allSatisfy { $0.isPass }
            if allPassed {
                self.onSuccess?()
            }
        }
    }
}
