import Foundation

public protocol DatabaseServiceProtocol {
    func loadQuestions() -> [Question]
}

public class DatabaseService: DatabaseServiceProtocol {
    public init() {}
    
    public func loadQuestions() -> [Question] {
        var dsaList: [Question] = []
        
        // Load DSA questions from dsa_questions.json (Bundle or local path)
        var dsaUrl = Bundle.main.url(forResource: "dsa_questions", withExtension: "json")
        if dsaUrl == nil {
            let localPath = "MyApp/Resources/dsa_questions.json"
            if FileManager.default.fileExists(atPath: localPath) {
                dsaUrl = URL(fileURLWithPath: localPath)
            }
        }
        
        if let url = dsaUrl {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                dsaList = try decoder.decode([Question].self, from: data)
            } catch {
                print("DatabaseService: Error decoding dsa_questions JSON: \(error.localizedDescription)")
            }
        }
        
        if dsaList.isEmpty {
            dsaList = fallbackDSAQuestions
        }
        
        // Load Swift practice questions from swift_questions.json
        var swiftList: [Question] = []
        var swiftUrl = Bundle.main.url(forResource: "swift_questions", withExtension: "json")
        if swiftUrl == nil {
            let localPath = "MyApp/Resources/swift_questions.json"
            if FileManager.default.fileExists(atPath: localPath) {
                swiftUrl = URL(fileURLWithPath: localPath)
            }
        }
        
        if let url = swiftUrl {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                swiftList = try decoder.decode([Question].self, from: data)
            } catch {
                print("DatabaseService: Error decoding swift_questions JSON: \(error.localizedDescription)")
            }
        }
        
        if swiftList.isEmpty {
            swiftList = fallbackSwiftQuestions
        }
        
        let total = dsaList + swiftList
        print("DatabaseService: Total questions loaded: \(total.count) (DSA: \(dsaList.count), Swift: \(swiftList.count))")
        return total
    }
    
    // MARK: - Resilient Fallback DSA Questions
    private var fallbackDSAQuestions: [Question] {
        return [
            Question(
                id: "two_sum",
                title: "1. Two Sum",
                category: "dsa",
                difficulty: "Easy",
                topics: ["Array", "Hash Table"],
                description: "Given an array of integers nums and an integer target, return indices of the two numbers such that they add up to target. You may assume that each input would have exactly one solution, and you may not use the same element twice.",
                templateCode: """
class Solution {
    func twoSum(_ nums: [Int], _ target: Int) -> [Int] {
        
    }
}
""",
                solutionCode: """
class Solution {
    func twoSum(_ nums: [Int], _ target: Int) -> [Int] {
        var map = [Int: Int]()
        for (i, num) in nums.enumerated() {
            let diff = target - num
            if let index = map[diff] {
                return [index, i]
            }
            map[num] = i
        }
        return []
    }
}
""",
                testHarness: """
let solution = Solution()
struct TestCase {
    let nums: [Int]
    let target: Int
    let expected: [Int]
    let name: String
}
let testCases = [
    TestCase(nums: [2, 7, 11, 15], target: 9, expected: [0, 1], name: "Example 1 ([2,7,11,15], target 9)"),
    TestCase(nums: [3, 2, 4], target: 6, expected: [1, 2], name: "Example 2 ([3,2,4], target 6)"),
    TestCase(nums: [3, 3], target: 6, expected: [0, 1], name: "Example 3 ([3,3], target 6)")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = solution.twoSum(tc.nums, tc.target)
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
            ),
            Question(
                id: "rod_cutting",
                title: "Rod Cutting Problem",
                category: "dsa",
                difficulty: "Medium",
                topics: ["DP", "Unbounded Knapsack"],
                description: "Given a rod of length n and an array price[]. price[i] denotes the price of a piece of length i. Determine the maximum amount obtained by cutting the rod into pieces and selling the pieces.\n\nNote: price[0] is always 0.",
                templateCode: """
class Solution {
    func cutRod(_ price: [Int]) -> Int {
        
    }
}
""",
                solutionCode: """
class Solution {
    func cutRod(_ price: [Int]) -> Int {
        let n = price.count - 1
        if n <= 0 { return 0 }
        var dp = Array(repeating: 0, count: n + 1)
        
        for i in 1...n {
            var maxVal = 0
            for j in 1...i {
                if j < price.count {
                    maxVal = max(maxVal, price[j] + dp[i - j])
                }
            }
            dp[i] = maxVal
        }
        
        return dp[n]
    }
}
""",
                testHarness: """
let solution = Solution()
struct TestCase {
    let price: [Int]
    let expected: Int
    let name: String
}
let testCases = [
    TestCase(price: [0, 1, 5, 8, 9, 10, 17, 17, 20], expected: 22, name: "Example 1 (Cut into lengths 2 & 6 -> 5+17=22)"),
    TestCase(price: [0, 3, 5, 8, 9, 10, 17, 17, 20], expected: 24, name: "Example 2 (8 cuts of length 1 -> 8*3=24)"),
    TestCase(price: [0, 3], expected: 3, name: "Example 3 (Single length 1 rod)"),
    TestCase(price: [0, 1, 1, 1, 100], expected: 100, name: "Edge Case 1 (Single full length piece optimal)"),
    TestCase(price: [0, 0, 0, 0], expected: 0, name: "Edge Case 2 (All zero prices)"),
    TestCase(price: [0], expected: 0, name: "Edge Case 3 (Zero length rod)"),
    TestCase(price: [0, 2, 5, 9, 10, 15, 17, 20, 24, 30], expected: 30, name: "Normal Case (Length 9 rod)")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = solution.cutRod(tc.price)
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
                title: "1. Network GET Request (URLSession)",
                category: "swiftPractice",
                difficulty: "Easy",
                topics: ["URLSession", "Codable", "Networking"],
                description: "Write Swift code to perform an HTTP GET request to https://jsonplaceholder.typicode.com/todos/1, decode the JSON payload into a `Todo` model format, and print the output details.",
                templateCode: """
import Foundation

// 1. Define model format matching the API response
struct Todo: Codable {
    // TODO: Define properties matching JSON keys (userId, id, title, completed)
}

// 2. Perform GET Call and decode data
func performFetch() {
    let urlString = "https://jsonplaceholder.typicode.com/todos/1"
    guard let url = URL(string: urlString) else { return }
    
    print("Sending GET request to \\(urlString)...")
    
    // TODO: Use URLSession.shared.dataTask(with: url) to fetch data
    // TODO: Decode data using JSONDecoder() into Todo struct
    // TODO: Print the decoded Todo details
    
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
    let semaphore = DispatchSemaphore(value: 0)
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        defer { semaphore.signal() }
        guard let data = data else { return }
        do {
            let todo = try JSONDecoder().decode(Todo.self, from: data)
            let statusStr = todo.completed ? "Completed ✅" : "Pending ⏳"
            print("\\n=== Response Successfully Decoded ===")
            print("User ID: \\(todo.userId)")
            print("Todo ID: \\(todo.id)")
            print("Title:   \\(todo.title)")
            print("Status:  \\(statusStr)")
            print("=====================================")
        } catch {
            print("Error: \\(error)")
        }
    }
    task.resume()
    semaphore.wait()
}
performFetch()
""",
                testHarness: "",
                networkUrl: "https://jsonplaceholder.typicode.com/todos/1"
            ),
            Question(
                id: "post_todo",
                title: "2. Network POST Request (Codable)",
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
        
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
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
        semaphore.wait()
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
    let semaphore = DispatchSemaphore(value: 0)
    do {
        request.httpBody = try JSONEncoder().encode(newTodo)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            guard let data = data else { return }
            do {
                let todo = try JSONDecoder().decode(Todo.self, from: data)
                print("User ID: \\(todo.userId)")
                print("Todo ID: \\(todo.id ?? 0)")
                print("Title: \\(todo.title)")
                print("Status: \\(todo.completed ? \\"Completed ✅\\" : \\"Pending\\")")
            } catch {
                print("Error: \\(error)")
            }
        } 
        task.resume()
        semaphore.wait()
    } catch {}
}
createTodo()
""",
                testHarness: "",
                networkUrl: "https://jsonplaceholder.typicode.com/todos"
            ),
            Question(
                id: "retain_cycle_fix",
                title: "3. ARC & Memory Leaks (Retain Cycle Fix)",
                category: "swiftPractice",
                difficulty: "Hard",
                topics: ["ARC", "Memory Management", "Closures"],
                description: "Fix a memory leak! The DataLoader class creates a strong retain cycle because the completion closure captures 'self' strongly while 'self' holds a reference to the closure handler.\n\nUse [weak self] inside the closure capture list and verify that deinit is executed when the object reference is cleared.",
                templateCode: """
import Foundation

class DataLoader {
    var onDataLoaded: ((String) -> Void)?
    var name: String = "UserDataFetcher"
    
    init() {
        print("[Init] DataLoader allocated in memory")
    }
    
    func startFetching() {
        // TODO: Fix the retain cycle below by adding [weak self] in capture list
        self.onDataLoaded = { data in
            print("Data received in \\(self.name): \\(data)")
        }
    }
    
    deinit {
        print("[Deinit] ✅ DataLoader successfully deallocated! (No Retain Cycle)")
    }
}

func testMemoryLeak() {
    var loader: DataLoader? = DataLoader()
    loader?.startFetching()
    loader?.onDataLoaded?("Payload 101")
    
    print("Clearing loader reference...")
    loader = nil // If retain cycle exists, deinit will NOT be called!
}

testMemoryLeak()
""",
                solutionCode: """
import Foundation

class DataLoader {
    var onDataLoaded: ((String) -> Void)?
    var name: String = "UserDataFetcher"
    
    init() {
        print("[Init] DataLoader allocated in memory")
    }
    
    func startFetching() {
        self.onDataLoaded = { [weak self] data in
            guard let self = self else { return }
            print("Data received in \\(self.name): \\(data)")
        }
    }
    
    deinit {
        print("[Deinit] ✅ DataLoader successfully deallocated! (No Retain Cycle)")
    }
}

func testMemoryLeak() {
    var loader: DataLoader? = DataLoader()
    loader?.startFetching()
    loader?.onDataLoaded?("Payload 101")
    
    print("Clearing loader reference...")
    loader = nil
}

testMemoryLeak()
""",
                testHarness: ""
            ),
            Question(
                id: "actor_cache",
                title: "4. Swift Concurrency (Thread-Safe Actor Cache)",
                category: "swiftPractice",
                difficulty: "Hard",
                topics: ["Actors", "Concurrency", "Data Race Safety"],
                description: "Implement a thread-safe in-memory cache using Swift's 'actor' keyword to guarantee isolation and data-race safety across concurrent background tasks.\n\nImplement set(key:value:) and get(key:) methods and access them asynchronously using await.",
                templateCode: """
import Foundation

actor ImageCache {
    private var cache = [String: String]()
    
    func set(key: String, value: String) {
        cache[key] = value
    }
    
    func get(key: String) -> String? {
        return cache[key]
    }
}

func runConcurrentTasks() async {
    let imageCache = ImageCache()
    
    await imageCache.set(key: "avatar_1", value: "https://cdn.example.com/user1.png")
    await imageCache.set(key: "avatar_2", value: "https://cdn.example.com/user2.png")
    
    if let url = await imageCache.get(key: "avatar_1") {
        print("✅ Retrieved from Actor Cache: \\(url)")
    }
}

Task {
    await runConcurrentTasks()
}
""",
                solutionCode: """
import Foundation

actor ImageCache {
    private var cache = [String: String]()
    
    func set(key: String, value: String) {
        cache[key] = value
    }
    
    func get(key: String) -> String? {
        return cache[key]
    }
}

func runConcurrentTasks() async {
    let imageCache = ImageCache()
    await imageCache.set(key: "avatar_1", value: "https://cdn.example.com/user1.png")
    await imageCache.set(key: "avatar_2", value: "https://cdn.example.com/user2.png")
    
    if let url = await imageCache.get(key: "avatar_1") {
        print("=== Thread-Safe Actor Cache Test ===")
        print("Key: avatar_1 -> Value: \\(url)")
        print("====================================")
    }
}

let semaphore = DispatchSemaphore(value: 0)
Task {
    await runConcurrentTasks()
    semaphore.signal()
}
semaphore.wait()
""",
                testHarness: ""
            ),
            Question(
                id: "combine_search_debounce",
                title: "5. Combine Reactive Search Bar (Debouncer)",
                category: "swiftPractice",
                difficulty: "Hard",
                topics: ["Combine", "Publishers", "Debounce"],
                description: "Build a reactive search debouncer using Combine's PassthroughSubject. Use .debounce() to throttle rapid user keystrokes so network calls are only fired after 100ms of pause.",
                templateCode: """
import Foundation
import Combine

class SearchViewModel {
    let searchPublisher = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        searchPublisher
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { query in
                print("🔎 Executing Search API query: '\\(query)'")
            }
            .store(in: &cancellables)
    }
}

let vm = SearchViewModel()
print("Simulating fast keystrokes: S -> Sw -> Swi -> Swift...")
vm.searchPublisher.send("S")
vm.searchPublisher.send("Sw")
vm.searchPublisher.send("Swi")
vm.searchPublisher.send("Swift")
""",
                solutionCode: """
import Foundation
import Combine

class SearchViewModel {
    let searchPublisher = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        searchPublisher
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { query in
                print("=== Combine Search Debouncer Result ===")
                print("🔎 Executing Search API query: '\\(query)'")
                print("=======================================")
            }
            .store(in: &cancellables)
    }
}

let vm = SearchViewModel()
vm.searchPublisher.send("S")
vm.searchPublisher.send("Sw")
vm.searchPublisher.send("Swi")
vm.searchPublisher.send("Swift")
RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
""",
                testHarness: ""
            ),
            Question(
                id: "userdefault_property_wrapper",
                title: "6. Custom @UserDefault Property Wrapper",
                category: "swiftPractice",
                difficulty: "Medium",
                topics: ["Property Wrappers", "Generics", "UserDefaults"],
                description: "Implement a custom generic @UserDefault property wrapper in Swift that automatically syncs struct properties with UserDefaults using a specified key and default fallback value.",
                templateCode: """
import Foundation

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    
    var wrappedValue: T {
        get {
            return (UserDefaults.standard.object(forKey: key) as? T) ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

struct AppSettings {
    @UserDefault(key: "is_dark_mode", defaultValue: false)
    static var isDarkMode: Bool
}

print("Initial Dark Mode:", AppSettings.isDarkMode)
AppSettings.isDarkMode = true
print("Updated Dark Mode:", AppSettings.isDarkMode)
""",
                solutionCode: """
import Foundation

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    
    var wrappedValue: T {
        get {
            return (UserDefaults.standard.object(forKey: key) as? T) ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

struct AppSettings {
    @UserDefault(key: "is_dark_mode", defaultValue: false)
    static var isDarkMode: Bool
}

print("=== @UserDefault Property Wrapper Test ===")
print("Initial Dark Mode:", AppSettings.isDarkMode)
AppSettings.isDarkMode = true
print("Updated Dark Mode:", AppSettings.isDarkMode)
print("=========================================")
""",
                testHarness: ""
            ),
            Question(
                id: "cow_optimization",
                title: "7. Copy-on-Write (COW) Custom Data Structure",
                category: "swiftPractice",
                difficulty: "Hard",
                topics: ["Copy-On-Write", "COW", "Memory Optimization"],
                description: "Implement a Copy-on-Write (COW) optimization for a custom value type using an internal reference box class and isKnownUniquelyReferenced.",
                templateCode: """
import Foundation

private class StorageBox<T> {
    var value: T
    init(value: T) { self.value = value }
}

struct CustomBuffer<T> {
    private var box: StorageBox<T>
    
    init(value: T) {
        self.box = StorageBox(value: value)
    }
    
    var value: T {
        get { return box.value }
        set {
            if !isKnownUniquelyReferenced(&box) {
                print("📋 Unique copy created due to COW mutation!")
                box = StorageBox(value: newValue)
            } else {
                print("⚡ In-place mutation (no copy needed)")
                box.value = newValue
            }
        }
    }
}

var buffer1 = CustomBuffer(value: "Initial Payload")
var buffer2 = buffer1 // Shared storage box!

buffer2.value = "Mutated Payload"
print("Buffer 1:", buffer1.value)
print("Buffer 2:", buffer2.value)
""",
                solutionCode: """
import Foundation

private class StorageBox<T> {
    var value: T
    init(value: T) { self.value = value }
}

struct CustomBuffer<T> {
    private var box: StorageBox<T>
    
    init(value: T) {
        self.box = StorageBox(value: value)
    }
    
    var value: T {
        get { return box.value }
        set {
            if !isKnownUniquelyReferenced(&box) {
                print("📋 Unique copy created due to COW mutation!")
                box = StorageBox(value: newValue)
            } else {
                print("⚡ In-place mutation (no copy needed)")
                box.value = newValue
            }
        }
    }
}

print("=== Copy-on-Write (COW) Test ===")
var buffer1 = CustomBuffer(value: "Initial Payload")
var buffer2 = buffer1
buffer2.value = "Mutated Payload"
print("Buffer 1:", buffer1.value)
print("Buffer 2:", buffer2.value)
print("=================================")
""",
                testHarness: ""
            )
        ]
    }
}
