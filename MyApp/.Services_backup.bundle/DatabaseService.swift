import Foundation

public protocol DatabaseServiceProtocol {
    func loadQuestions() -> [Question]
}

public class DatabaseService: DatabaseServiceProtocol {
    public init() {}
    
    public func loadQuestions() -> [Question] {
        var dsaList: [Question] = []
        var swiftList: [Question] = []
        
        // 1. Try to load DSA questions from dsa_questions.json
        if let dsaUrl = Bundle.main.url(forResource: "dsa_questions", withExtension: "json") {
            do {
                let data = try Data(contentsOf: dsaUrl)
                let decoder = JSONDecoder()
                dsaList = try decoder.decode([Question].self, from: data)
            } catch {
                print("DatabaseService: Error decoding dsa_questions JSON: \(error.localizedDescription)")
            }
        }
        
        if dsaList.isEmpty {
            dsaList = fallbackDSAQuestions
        }
        
        // 2. Try to load Swift questions from swift_questions.json
        if let swiftUrl = Bundle.main.url(forResource: "swift_questions", withExtension: "json") {
            do {
                let data = try Data(contentsOf: swiftUrl)
                let decoder = JSONDecoder()
                swiftList = try decoder.decode([Question].self, from: data)
            } catch {
                print("DatabaseService: Error decoding swift_questions JSON: \(error.localizedDescription)")
            }
        }
        
        if swiftList.isEmpty {
            swiftList = fallbackSwiftQuestions
        }
        
        let finalQuestions = dsaList + swiftList
        print("DatabaseService: Total questions loaded: \(finalQuestions.count)")
        print("DatabaseService: DSA questions: \(dsaList.map { $0.id })")
        print("DatabaseService: Swift questions: \(swiftList.map { $0.id })")
        return finalQuestions
    }
    
    // MARK: - Resilient Fallback DSA Questions
    private var fallbackDSAQuestions: [Question] {
        return [
            Question(
                id: "maximal_square",
                title: "221. Maximal Square",
                category: "dsa",
                difficulty: "Medium",
                topics: ["DP", "Matrix"],
                description: "Given an m x n binary matrix filled with 0's and 1's, find the largest square containing only 1's and return its area.",
                templateCode: """
class Solution {
    func maximalSquare(_ matrix: [[Character]]) -> Int {
        
    }
}
""",
                solutionCode: """
class Solution {
    func maximalSquare(_ matrix: [[Character]]) -> Int {
        guard !matrix.isEmpty else { return 0 }
        let m = matrix.count
        let n = matrix[0].count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        var maxLen = 0
        
        for i in 1...m {
            for j in 1...n {
                if matrix[i - 1][j - 1] == "1" {
                    dp[i][j] = min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]) + 1
                    maxLen = max(maxLen, dp[i][j])
                } 
            }
        }
        
        return maxLen * maxLen
    }
}
""",
                testHarness: """
let solution = Solution()
struct TestCase {
    let matrix: [[Character]]
    let expected: Int
    let name: String
}
let testCases = [
    TestCase(matrix: [["1","0","1","0","0"],["1","0","1","1","1"],["1","1","1","1","1"],["1","0","0","1","0"]], expected: 4, name: "Example 1 (Normal matrix)"),
    TestCase(matrix: [["0","1"],["1","0"]], expected: 1, name: "Example 2 (2x2 matrix)"),
    TestCase(matrix: [["0"]], expected: 0, name: "Example 3 (Single cell 0)"),
    TestCase(matrix: [], expected: 0, name: "Edge Case 1 (Empty matrix)"),
    TestCase(matrix: [["1", "1", "1"]], expected: 1, name: "Edge Case 2 (1x3 all ones)"),
    TestCase(matrix: [["0","0"],["0","0"]], expected: 0, name: "Edge Case 3 (2x2 all zeros)"),
    TestCase(matrix: [["1","1","1"],["1","1","1"],["1","1","1"]], expected: 9, name: "Normal Case (3x3 all ones)")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = solution.maximalSquare(tc.matrix)
    let endTime = DispatchTime.now()
    let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
    let timeInterval = Double(nanoTime) / 1_000_000.0
    if result == tc.expected {
        print("CASE \\(index) | PASS | Name: \\(tc.name) | Output: \\(result) | Expected: \\(tc.expected) | Time: \\(String(format: "%.3f", timeInterval))ms")
        passedCount += 1
    } else {
        print("CASE \\(index) | FAIL | Name: \\(tc.name) | Output: \\(result) | Expected: \\(tc.expected) | Time: \\(String(format: "%.3f", timeInterval))ms")
    }
}
print("SUMMARY | \\(passedCount)/\\(testCases.count) PASSED")
print("---DSA_TEST_RESULTS_END---")
"""
            ),
            Question(
                id: "climb_stairs",
                title: "70. Climbing Stairs",
                category: "dsa",
                difficulty: "Easy",
                topics: ["DP", "Math"],
                description: "You are climbing a staircase. It takes n steps to reach the top. Each time you can either climb 1 or 2 steps. In how many distinct ways can you climb to the top?",
                templateCode: """
class Solution {
    func climbStairs(_ n: Int) -> Int {
        
    }
}
""",
                solutionCode: """
class Solution {
    func climbStairs(_ n: Int) -> Int {
        if n <= 2 { return n }
        var first = 1
        var second = 2
        for _ in 3...n {
            let third = first + second
            first = second
            second = third
        }
        return second
    }
}
""",
                testHarness: """
let solution = Solution()
struct TestCase {
    let n: Int
    let expected: Int
    let name: String
}
let testCases = [
    TestCase(n: 2, expected: 2, name: "Example 1 (n = 2)"),
    TestCase(n: 3, expected: 3, name: "Example 2 (n = 3)"),
    TestCase(n: 5, expected: 8, name: "n = 5"),
    TestCase(n: 1, expected: 1, name: "Edge Case (n = 1)"),
    TestCase(n: 10, expected: 89, name: "n = 10")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = solution.climbStairs(tc.n)
    let endTime = DispatchTime.now()
    let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
    let timeInterval = Double(nanoTime) / 1_000_000.0
    if result == tc.expected {
        print("CASE \\(index) | PASS | Name: \\(tc.name) | Output: \\(result) | Expected: \\(tc.expected) | Time: \\(String(format: "%.3f", timeInterval))ms")
        passedCount += 1
    } else {
        print("CASE \\(index) | FAIL | Name: \\(tc.name) | Output: \\(result) | Expected: \\(tc.expected) | Time: \\(String(format: "%.3f", timeInterval))ms")
    }
}
print("SUMMARY | \\(passedCount)/\\(testCases.count) PASSED")
print("---DSA_TEST_RESULTS_END---")
"""
            )
        ]
    }
    
    // MARK: - Resilient Fallback Swift Questions
    private var fallbackSwiftQuestions: [Question] {
        return [
            Question(
                id: "fetch_todo",
                title: "Network GET Request",
                category: "swiftPractice",
                difficulty: "Easy",
                topics: ["URLSession", "Codable"],
                description: "Write Swift code to perform an HTTP GET request to a JSON endpoint, decode the response payload into a proper model format, and print the output details.",
                templateCode: """
import Foundation

// 1. Define model format matching the API response
struct Todo: Codable {
    let userId: Int
    let id: Int
    let title: String
    let completed: Bool
}

// 2. Perform GET Call and decode data
func performFetch() {
    let urlString = "https://jsonplaceholder.typicode.com/todos/1"
    guard let url = URL(string: urlString) else { return }
    
    print("Sending GET request to \\(urlString)...")
    
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Error: \\(error.localizedDescription)")
            return
        }
        
        guard let data = data else { return }
        
        do {
            let decoder = JSONDecoder()
            let todo = try decoder.decode(Todo.self, from: data)
            
            print("\\n=== Response Successfully Decoded ===")
            print("User ID: \\(todo.userId)")
            print("Todo ID: \\(todo.id)")
            print("Title:   \\(todo.title)")
            print("Status:  \\(todo.completed ? \\"Completed ✅\\" : \\"Incomplete ⏳\\")")
            print("=====================================")
        } catch {
            print("Decoding Error: \\(error.localizedDescription)")
        }
    }
    task.resume()
}

performFetch()
""",
                solutionCode: """
import Foundation

struct Todo: Codable {
    let userId: Int
    let id: Int
    let title: String
    let completed: Bool
}

func performFetch() {
    let urlString = "https://jsonplaceholder.typicode.com/todos/1"
    guard let url = URL(string: urlString) else { return }
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        guard let data = data else { return }
        do {
            let todo = try JSONDecoder().decode(Todo.self, from: data)
            print("User ID: \\(todo.userId)")
            print("Todo ID: \\(todo.id)")
            print("Title: \\(todo.title)")
            print("Status: \\(todo.completed ? \\"Completed\\" : \\"Pending\\")")
        } catch {
            print("Error: \\(error)")
        }
    }
    task.resume()
}
performFetch()
""",
                testHarness: "",
                networkUrl: "https://jsonplaceholder.typicode.com/todos/1"
            ),
            Question(
                id: "post_todo",
                title: "Network POST Request",
                category: "swiftPractice",
                difficulty: "Medium",
                topics: ["URLSession", "HTTP POST", "Codable"],
                description: "Perform an HTTP POST request to https://jsonplaceholder.typicode.com/todos with a JSON body containing title and completed status. Print the parsed API response showing the newly created Todo item with its assigned ID.",
                templateCode: """
import Foundation

struct Todo: Codable {
    let userId: Int
    let id: Int?
    let title: String
    let completed: Bool
}

func createTodo() {
    let url = URL(string: "https://jsonplaceholder.typicode.com/todos")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let newTodo = Todo(userId: 1, id: nil, title: "Learn Swift Architecture", completed: true)
    
    do {
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(newTodo)
        
        print("Sending POST request to /todos...")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else { return }
            do {
                let todo = try JSONDecoder().decode(Todo.self, from: data)
                print("\\n=== Response Successfully Decoded ===")
                print("User ID: \\(todo.userId)")
                print("Todo ID: \\(todo.id ?? 0)")
                print("Title:   \\(todo.title)")
                print("Status:  \\(todo.completed ? \\"Completed ✅\\" : \\"Incomplete ⏳\\")")
                print("=====================================")
            } catch {
                print("Decoding Error: \\(error)")
            } 
        }
        task.resume()
    } catch {
        print("Encoding Error: \\(error)")
    }
}

createTodo()
""",
                solutionCode: """
import Foundation

struct Todo: Codable {
    let userId: Int
    let id: Int?
    let title: String
    let completed: Bool
}

func createTodo() {
    let url = URL(string: "https://jsonplaceholder.typicode.com/todos")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let newTodo = Todo(userId: 1, id: nil, title: "Learn Swift Architecture", completed: true)
    do {
        request.httpBody = try JSONEncoder().encode(newTodo)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else { return }
            do {
                let todo = try JSONDecoder().decode(Todo.self, from: data)
                print("User ID: \\(todo.userId)")
                print("Todo ID: \\(todo.id ?? 0)")
                print("Title: \\(todo.title)")
                print("Status: \\(todo.completed ? \\"Completed\\" : \\"Pending\\")")
            } catch {
                print("Error: \\(error)")
            }
        } 
        task.resume()
    } catch {}
}
createTodo()
""",
                testHarness: "",
                networkUrl: "https://jsonplaceholder.typicode.com/todos"
            )
        ]
    }
}
