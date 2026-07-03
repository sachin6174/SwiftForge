import Foundation
import Combine

@MainActor
public class SwiftPracticeViewModel: ObservableObject {
    @Published public var currentQuestion: Question?
    @Published public var code: String = ""
    @Published public var isRunning = false
    @Published public var consoleOutput = "Run script to view output."
    @Published public var decodedTodo: SimulatedTodo? = nil
    @Published public var networkError: String? = nil
    @Published public var networkAnimationStep = 0
    
    private let codeRunner: CodeRunnerProtocol
    public var onSuccess: (() -> Void)?
    
    public init(codeRunner: CodeRunnerProtocol = CodeRunnerService()) {
        self.codeRunner = codeRunner
    }
    
    public func loadQuestion(_ question: Question, draft: String? = nil) {
        self.currentQuestion = question
        self.code = draft ?? question.templateCode
        self.decodedTodo = nil
        self.consoleOutput = "Loaded \(question.title). Ready to edit."
        self.networkError = nil
        self.networkAnimationStep = 0
    }
    
    public func resetCode() {
        guard let question = currentQuestion else { return }
        self.code = question.templateCode
        self.decodedTodo = nil
        self.consoleOutput = "Code reset to template."
        self.networkError = nil
        self.networkAnimationStep = 0
    }
    
    public func loadSolution() {
        guard let question = currentQuestion else { return }
        self.code = question.solutionCode
        self.decodedTodo = nil
        self.consoleOutput = "Working solution loaded."
        self.networkError = nil
        self.networkAnimationStep = 0
    }
    
    public func runCode() async {
        guard let question = currentQuestion else { return }
        self.isRunning = true
        self.consoleOutput = "Compiling and launching Swift network script...\n"
        self.decodedTodo = nil
        self.networkError = nil
        self.networkAnimationStep = 1
        
        // Simulating packet flow animation while establishing connection
        for step in 2...3 {
            try? await Task.sleep(nanoseconds: 600_000_000)
            self.networkAnimationStep = step
        }
        
        let result = await codeRunner.runSwiftCode(code: code, appendHarness: "\nRunLoop.main.run(until: Date(timeIntervalSinceNow: 4.0))")
        
        if result.exitCode == -2 {
            self.consoleOutput += "Native Swift execution unavailable. Running in Sandbox simulation mode...\n"
            await self.runJSFallback()
        } else if result.exitCode != 0 {
            self.isRunning = false
            self.networkAnimationStep = 0
            self.networkError = result.stderr.isEmpty ? result.stdout : result.stderr
            self.consoleOutput = "Compilation Failed.\n\n" + (self.networkError ?? "")
        } else {
            self.isRunning = false
            self.consoleOutput = result.stdout
            self.networkAnimationStep = 4
            self.parseOutput(result.stdout)
        }
    }
    
    private func runJSFallback() async {
        guard let question = currentQuestion else { return }
        let targetUrlStr = question.networkUrl ?? "https://jsonplaceholder.typicode.com/todos/1"
        
        let containsURL = code.contains(targetUrlStr) || code.lowercased().contains("url")
        
        if !containsURL {
            self.isRunning = false
            self.networkAnimationStep = 0
            self.consoleOutput += "Error: Target URL '\(targetUrlStr)' not found in script.\n"
            return
        }
        
        guard let url = URL(string: targetUrlStr) else {
            self.isRunning = false
            self.networkAnimationStep = 0
            self.consoleOutput += "Error: Invalid URL '\(targetUrlStr)'\n"
            return
        }
        
        do {
            var request = URLRequest(url: url)
            if question.id == "post_todo" {
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let bodyDict = ["userId": 1, "id": 101, "title": "Learn Swift Architecture", "completed": true] as [String : Any]
                request.httpBody = try? JSONSerialization.data(withJSONObject: bodyDict, options: [])
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.isRunning = false
                self.networkAnimationStep = 0
                self.consoleOutput += "Error: Invalid HTTP Response\n"
                return
            }
            
            let headerStr = "HTTP/1.1 \(httpResponse.statusCode) OK\n" +
                "Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "application/json")\n" +
                "Content-Length: \(data.count)\n"
            
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            
            self.isRunning = false
            self.consoleOutput += "\n--- Simulated Response Received ---\n"
            self.consoleOutput += headerStr + "\n"
            self.consoleOutput += "Response Body:\n"
            self.consoleOutput += bodyStr + "\n"
            
            self.networkAnimationStep = 4
            self.parseOutput(bodyStr)
        } catch {
            self.isRunning = false
            self.networkAnimationStep = 0
            self.consoleOutput += "Network request failed: \(error.localizedDescription)\n"
        }
    }
    
    private func parseOutput(_ stdout: String) {
        let lines = stdout.components(separatedBy: .newlines)
        var userId = 1
        var id = 1
        var title = "delectus aut autem"
        var completed = false
        var foundAny = false
        
        if stdout.contains("\"userId\"") {
            if let data = stdout.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                userId = json["userId"] as? Int ?? 1
                id = json["id"] as? Int ?? 101
                title = json["title"] as? String ?? "Learn Swift Architecture"
                completed = json["completed"] as? Bool ?? true
                foundAny = true
            }
        }
        
        if !foundAny {
            for line in lines {
                let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if clean.contains("User ID:") || clean.contains("userId:") {
                    let val = clean.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                    userId = Int(val) ?? 1
                    foundAny = true
                } else if clean.contains("Todo ID:") || clean.contains("id:") {
                    let val = clean.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                    id = Int(val) ?? 1
                    foundAny = true
                } else if clean.contains("Title:") || clean.contains("title:") {
                    let val = clean.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                    title = val.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces)
                    foundAny = true
                } else if clean.contains("Status:") || clean.contains("completed:") || clean.contains("Completed:") {
                    let val = clean.lowercased()
                    completed = val.contains("true") || val.contains("yes") || val.contains("completed") || val.contains("✅")
                    foundAny = true
                }
            }
        }
        
        let targetTodo = SimulatedTodo(userId: userId, todoId: id, title: title, completed: completed)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.networkAnimationStep = 5
            self.decodedTodo = targetTodo
            self.onSuccess?()
        }
    }
}
