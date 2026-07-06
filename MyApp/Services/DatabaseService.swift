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
        // TODO: Write your solution here
        return []
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
    TestCase(nums: [3, 3], target: 6, expected: [0, 1], name: "Example 3 ([3,3], target 6)"),
    TestCase(nums: [-3, 4, 3, 90], target: 0, expected: [0, 2], name: "Negative Numbers (target 0)"),
    TestCase(nums: [1, 5, 5, 8], target: 10, expected: [1, 2], name: "Duplicate Values ([5,5], target 10)"),
    TestCase(nums: [0, 4, 3, 0], target: 0, expected: [0, 3], name: "Zeroes Match ([0,0], target 0)"),
    TestCase(nums: [-10, -1, -5, -4], target: -14, expected: [0, 3], name: "All Negative ([-10, -4], target -14)"),
    TestCase(nums: [2, 7], target: 9, expected: [0, 1], name: "Minimum 2 Elements"),
    TestCase(nums: [100, 1, 2, 3, 4, 5, 6, 7, 8, 9, 200], target: 300, expected: [0, 10], name: "Extreme Ends (100 + 200)"),
    TestCase(nums: [5, 7, 9, 11, 13, 15, 17, 19, 21, 23], target: 44, expected: [8, 9], name: "Large Sequence Ends"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], target: 19, expected: [8, 9], name: "Consecutive Array (9 + 10)"),
    TestCase(nums: [-50, -40, -30, -20, -10, 0, 10, 20, 30, 40, 50], target: 0, expected: [4, 6], name: "Symmetric Neg/Pos (-50 + 50)"),
    TestCase(nums: [1000000, 500000, 500000], target: 1000000, expected: [1, 2], name: "Large Integers (500k + 500k)"),
    TestCase(nums: [1, 3, 5, 7, 9, 2, 4, 6, 8, 10], target: 12, expected: [2, 3], name: "Odd/Even Mixed (3 + 9)"),
    TestCase(nums: [10, 20, 30, 40, 50, 60, 70, 80], target: 150, expected: [6, 7], name: "Multiples of 10"),
    TestCase(nums: [9, 8, 7, 6, 5, 4, 3, 2, 1], target: 3, expected: [7, 8], name: "Descending Array (2 + 1)"),
    TestCase(nums: [-1, 0, 1], target: 0, expected: [0, 2], name: "Zero with Pos/Neg"),
    TestCase(nums: [100, -100], target: 0, expected: [0, 1], name: "Opposite Pair"),
    TestCase(nums: [4, 4, 4, 4], target: 8, expected: [0, 1], name: "Repeated Identical Values"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20], target: 39, expected: [18, 19], name: "20-Element Stress Test"),
    TestCase(nums: [1, 2, 3, 4, 5], target: 6, expected: [1, 3], name: "Array Size 5 Ends (1 + 5)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6], target: 7, expected: [2, 3], name: "Array Size 6 Ends (1 + 6)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7], target: 8, expected: [2, 4], name: "Array Size 7 Ends (1 + 7)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8], target: 9, expected: [3, 4], name: "Array Size 8 Ends (1 + 8)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9], target: 10, expected: [3, 5], name: "Array Size 9 Ends (1 + 9)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], target: 11, expected: [4, 5], name: "Array Size 10 Ends (1 + 10)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], target: 12, expected: [4, 6], name: "Array Size 11 Ends (1 + 11)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], target: 13, expected: [5, 6], name: "Array Size 12 Ends (1 + 12)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], target: 14, expected: [5, 7], name: "Array Size 13 Ends (1 + 13)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], target: 15, expected: [6, 7], name: "Array Size 14 Ends (1 + 14)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], target: 16, expected: [6, 8], name: "Array Size 15 Ends (1 + 15)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], target: 17, expected: [7, 8], name: "Array Size 16 Ends (1 + 16)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17], target: 18, expected: [7, 9], name: "Array Size 17 Ends (1 + 17)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], target: 19, expected: [8, 9], name: "Array Size 18 Ends (1 + 18)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19], target: 20, expected: [8, 10], name: "Array Size 19 Ends (1 + 19)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20], target: 21, expected: [9, 10], name: "Array Size 20 Ends (1 + 20)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21], target: 22, expected: [9, 11], name: "Array Size 21 Ends (1 + 21)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22], target: 23, expected: [10, 11], name: "Array Size 22 Ends (1 + 22)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23], target: 24, expected: [10, 12], name: "Array Size 23 Ends (1 + 23)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24], target: 25, expected: [11, 12], name: "Array Size 24 Ends (1 + 24)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25], target: 26, expected: [11, 13], name: "Array Size 25 Ends (1 + 25)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26], target: 27, expected: [12, 13], name: "Array Size 26 Ends (1 + 26)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27], target: 28, expected: [12, 14], name: "Array Size 27 Ends (1 + 27)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28], target: 29, expected: [13, 14], name: "Array Size 28 Ends (1 + 28)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], target: 30, expected: [13, 15], name: "Array Size 29 Ends (1 + 29)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30], target: 31, expected: [14, 15], name: "Array Size 30 Ends (1 + 30)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31], target: 32, expected: [14, 16], name: "Array Size 31 Ends (1 + 31)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32], target: 33, expected: [15, 16], name: "Array Size 32 Ends (1 + 32)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33], target: 34, expected: [15, 17], name: "Array Size 33 Ends (1 + 33)"),
    TestCase(nums: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34], target: 35, expected: [16, 17], name: "Array Size 34 Ends (1 + 34)")
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
                id: "valid_parentheses",
                title: "20. Valid Parentheses",
                category: "dsa",
                difficulty: "Easy",
                topics: ["Stack", "String"],
                description: "Given a string s containing just the characters '(', ')', '{', '}', '[' and ']', determine if the input string is valid.",
                templateCode: """
class Solution {
    func isValid(_ s: String) -> Bool {
        return false
    }
}
""",
                solutionCode: """
class Solution {
    func isValid(_ s: String) -> Bool {
        var stack = [Character]()
        let matching: [Character: Character] = [")": "(", "}": "{", "]": "["]
        for char in s {
            if let openBracket = matching[char] {
                if stack.isEmpty || stack.removeLast() != openBracket {
                    return false
                }
            } else {
                stack.append(char)
            }
        }
        return stack.isEmpty
    }
}
                testHarness: """
let solution = Solution()
struct TestCase {
    let s: String
    let expected: Bool
    let name: String
}
let testCases = [
    TestCase(s: "()", expected: true, name: "Example 1 (\\"()\\")"),
    TestCase(s: "()[]{}", expected: true, name: "Example 2 (\\"()[]{}\\")"),
    TestCase(s: "(]", expected: false, name: "Example 3 (\\"(]\\")"),
    TestCase(s: "([)]", expected: false, name: "Example 4 (\\"([)]\\")"),
    TestCase(s: "{[]}", expected: true, name: "Example 5 (\\"{[]}\\")"),
    TestCase(s: "", expected: true, name: "Empty String"),
    TestCase(s: "(((", expected: false, name: "Only Open Brackets"),
    TestCase(s: "))]", expected: false, name: "Only Close Brackets"),
    TestCase(s: "((({})[]))", expected: true, name: "Deeply Nested Balanced"),
    TestCase(s: "[", expected: false, name: "Single Character Open"),
    TestCase(s: "]", expected: false, name: "Single Character Close"),
    TestCase(s: "(((((((((())))))))))", expected: true, name: "10-Level Nested Round"),
    TestCase(s: "(((((((((()))))))))", expected: false, name: "Unbalanced 10-Level"),
    TestCase(s: "()()()()()()()()()()", expected: true, name: "10 Repeated Pairs"),
    TestCase(s: "()()()()()()()()()(", expected: false, name: "10 Repeated Trailing Open"),
    TestCase(s: "({[({[({[]})]})]})", expected: true, name: "Complex Symmetric Multilevel"),
    TestCase(s: "({[({[({[]})]})]})]", expected: false, name: "Complex Symmetric Extra Close"),
    TestCase(s: "}{", expected: false, name: "Inverted Pair Order"),
    TestCase(s: "[]}", expected: false, name: "Square and Unclosed Curly"),
    TestCase(s: "({[]})()[]{}", expected: true, name: "Combined Deep + Sequential"),
    TestCase(s: "(())", expected: true, name: "Round Brackets Depth 2"),
    TestCase(s: "[[[]]", expected: false, name: "Unbalanced Square Depth 3"),
    TestCase(s: "(((())))", expected: true, name: "Round Brackets Depth 4"),
    TestCase(s: "[[[[[]]]]", expected: false, name: "Unbalanced Square Depth 5"),
    TestCase(s: "(((((())))))", expected: true, name: "Round Brackets Depth 6"),
    TestCase(s: "[[[[[[[]]]]]]", expected: false, name: "Unbalanced Square Depth 7"),
    TestCase(s: "(((((((())))))))", expected: true, name: "Round Brackets Depth 8"),
    TestCase(s: "[[[[[[[[[]]]]]]]]", expected: false, name: "Unbalanced Square Depth 9"),
    TestCase(s: "(((((((((())))))))))", expected: true, name: "Round Brackets Depth 10"),
    TestCase(s: "[[[[[[[[[[[]]]]]]]]]]", expected: false, name: "Unbalanced Square Depth 11"),
    TestCase(s: "(((((((((((())))))))))))", expected: true, name: "Round Brackets Depth 12"),
    TestCase(s: "[[[[[[[[[[[[[]]]]]]]]]]]]", expected: false, name: "Unbalanced Square Depth 13"),
    TestCase(s: "(((((((((((((())))))))))))))", expected: true, name: "Round Brackets Depth 14"),
    TestCase(s: "[[[[[[[[[[[[[[[]]]]]]]]]]]]]]", expected: false, name: "Unbalanced Square Depth 15"),
    TestCase(s: "(((((((((((((((())))))))))))))))", expected: true, name: "Round Brackets Depth 16"),
    TestCase(s: "[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]", expected: false, name: "Unbalanced Square Depth 17"),
    TestCase(s: "(((((((((((((((((())))))))))))))))))", expected: true, name: "Round Brackets Depth 18"),
    TestCase(s: "[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]", expected: false, name: "Unbalanced Square Depth 19"),
    TestCase(s: "(((((((((((((((((((())))))))))))))))))))", expected: true, name: "Round Brackets Depth 20"),
    TestCase(s: "[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]", expected: false, name: "Unbalanced Square Depth 21"),
    TestCase(s: "(((((((((((((((((((((())))))))))))))))))))))", expected: true, name: "Round Brackets Depth 22"),
    TestCase(s: "[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]", expected: false, name: "Unbalanced Square Depth 23"),
    TestCase(s: "(((((((((((((((((((((((())))))))))))))))))))))))", expected: true, name: "Round Brackets Depth 24"),
    TestCase(s: "[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]]]", expected: false, name: "Unbalanced Square Depth 25"),
    TestCase(s: "(((((((((((((((((((((((((())))))))))))))))))))))))))", expected: true, name: "Round Brackets Depth 26"),
    TestCase(s: "[[[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]]]]]", expected: false, name: "Unbalanced Square Depth 27"),
    TestCase(s: "(((((((((((((((((((((((((((())))))))))))))))))))))))))))", expected: true, name: "Round Brackets Depth 28"),
    TestCase(s: "[[[[[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]]]]]]]", expected: false, name: "Unbalanced Square Depth 29"),
    TestCase(s: "(((((((((((((((((((((((((((((())))))))))))))))))))))))))))))", expected: true, name: "Round Brackets Depth 30"),
    TestCase(s: "[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]", expected: false, name: "Unbalanced Square Depth 31")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = solution.isValid(tc.s)
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
                id: "reverse_linked_list",
                title: "206. Reverse Linked List",
                category: "dsa",
                difficulty: "Easy",
                topics: ["Linked List", "Recursion"],
                description: "Given the head of a singly linked list, reverse the list, and return the reversed list.",
                templateCode: """
public class ListNode {
    public var val: Int
    public var next: ListNode?
    public init(_ val: Int, _ next: ListNode? = nil) {
        self.val = val
        self.next = next
    }
}

class Solution {
    func reverseList(_ head: ListNode?) -> ListNode? {
        return nil
    }
}
""",
                solutionCode: """
public class ListNode {
    public var val: Int
    public var next: ListNode?
    public init(_ val: Int, _ next: ListNode? = nil) {
        self.val = val
        self.next = next
    }
}

class Solution {
    func reverseList(_ head: ListNode?) -> ListNode? {
        var prev: ListNode? = nil
        var curr = head
        while curr != nil {
            let nextTemp = curr?.next
            curr?.next = prev
            prev = curr
            curr = nextTemp
        }
        return prev
    }
}
                testHarness: """
func arrayToList(_ arr: [Int]) -> ListNode? {
    let dummy = ListNode(0)
    var curr = dummy
    for val in arr {
        curr.next = ListNode(val)
        curr = curr.next!
    }
    return dummy.next
}

func listToArray(_ head: ListNode?) -> [Int] {
    var res = [Int]()
    var curr = head
    while curr != nil {
        res.append(curr!.val)
        curr = curr!.next
    }
    return res
}

let solution = Solution()
struct TestCase {
    let input: [Int]
    let expected: [Int]
    let name: String
}
let testCases = [
    TestCase(input: [1, 2, 3, 4, 5], expected: [5, 4, 3, 2, 1], name: "Example 1 ([1,2,3,4,5])"),
    TestCase(input: [1, 2], expected: [2, 1], name: "Example 2 ([1,2])"),
    TestCase(input: [], expected: [], name: "Example 3 ([])"),
    TestCase(input: [42], expected: [42], name: "Single Node ([42])"),
    TestCase(input: [7, 7], expected: [7, 7], name: "Two Identical Nodes"),
    TestCase(input: [-1, -2, -3], expected: [-3, -2, -1], name: "Negative Values"),
    TestCase(input: [1, -2, 3, -4, 5], expected: [5, -4, 3, -2, 1], name: "Alternating Signs"),
    TestCase(input: [1, 2, 3, 2, 1], expected: [1, 2, 3, 2, 1], name: "Palindromic List"),
    TestCase(input: [1, 1, 2, 2, 3, 3], expected: [3, 3, 2, 2, 1, 1], name: "Duplicate Adjacent Values"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], expected: [10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "10 Sequential Nodes"),
    TestCase(input: [0, 0, 0, 0, 0], expected: [0, 0, 0, 0, 0], name: "All Zeroes List"),
    TestCase(input: [100, 200, 300], expected: [300, 200, 100], name: "Large Values"),
    TestCase(input: [-100], expected: [-100], name: "Single Negative Node"),
    TestCase(input: [5, 4, 3, 2, 1], expected: [1, 2, 3, 4, 5], name: "Reversing Decreasing"),
    TestCase(input: [10, 9, 8, 7, 6], expected: [6, 7, 8, 9, 10], name: "Reversing Decreasing 5 Nodes"),
    TestCase(input: [2, 4, 6, 8], expected: [8, 6, 4, 2], name: "Even Numbers Sequence"),
    TestCase(input: [1, 3, 5, 7, 9], expected: [9, 7, 5, 3, 1], name: "Odd Numbers Sequence"),
    TestCase(input: [9, 9, 9], expected: [9, 9, 9], name: "Three Identical Nodes"),
    TestCase(input: [-5, 0, 5], expected: [5, 0, -5], name: "Negative Zero Positive"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20], expected: [20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "20-Node Long List"),
    TestCase(input: [1], expected: [1], name: "Sequential List Size 1"),
    TestCase(input: [1, 2], expected: [2, 1], name: "Sequential List Size 2"),
    TestCase(input: [1, 2, 3], expected: [3, 2, 1], name: "Sequential List Size 3"),
    TestCase(input: [1, 2, 3, 4], expected: [4, 3, 2, 1], name: "Sequential List Size 4"),
    TestCase(input: [1, 2, 3, 4, 5], expected: [5, 4, 3, 2, 1], name: "Sequential List Size 5"),
    TestCase(input: [1, 2, 3, 4, 5, 6], expected: [6, 5, 4, 3, 2, 1], name: "Sequential List Size 6"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7], expected: [7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 7"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8], expected: [8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 8"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9], expected: [9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 9"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], expected: [10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 10"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], expected: [11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 11"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], expected: [12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 12"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], expected: [13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 13"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], expected: [14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 14"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], expected: [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 15"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], expected: [16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 16"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17], expected: [17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 17"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18], expected: [18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 18"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19], expected: [19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 19"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20], expected: [20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 20"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21], expected: [21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 21"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22], expected: [22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 22"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23], expected: [23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 23"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24], expected: [24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 24"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25], expected: [25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 25"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26], expected: [26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 26"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27], expected: [27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 27"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28], expected: [28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 28"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], expected: [29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 29"),
    TestCase(input: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30], expected: [30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], name: "Sequential List Size 30")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let head = arrayToList(tc.input)
    let reversedHead = solution.reverseList(head)
    let result = listToArray(reversedHead)
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
    TestCase(matrix: [["1","0","1","0","0"],["1","0","1","1","1"],["1","1","1","1","1"],["1","0","0","1","0"]], expected: 4, name: "Example 1 (4x5 matrix)"),
    TestCase(matrix: [["0","1"],["1","0"]], expected: 1, name: "Example 2 (2x2 matrix)"),
    TestCase(matrix: [["0"]], expected: 0, name: "Example 3 (Single cell 0)"),
    TestCase(matrix: [["1"]], expected: 1, name: "Single cell 1"),
    TestCase(matrix: [], expected: 0, name: "Empty matrix"),
    TestCase(matrix: [["1","1","1"]], expected: 1, name: "1x3 All Ones"),
    TestCase(matrix: [["0","0"],["0","0"]], expected: 0, name: "2x2 All Zeros"),
    TestCase(matrix: [["1","1","1"],["1","1","1"],["1","1","1"]], expected: 9, name: "3x3 All Ones"),
    TestCase(matrix: [["1"],["1"],["1"]], expected: 1, name: "3x1 Single Column Ones"),
    TestCase(matrix: [["1","1"],["1","1"]], expected: 4, name: "2x2 All Ones"),
    TestCase(matrix: [["0","1","1"],["1","1","1"],["1","1","1"]], expected: 4, name: "3x3 Corner Zero"),
    TestCase(matrix: [["1","1","1","1"],["1","1","1","1"],["1","1","1","1"],["1","1","1","1"]], expected: 16, name: "4x4 All Ones"),
    TestCase(matrix: [["0","0","0"],["0","0","0"],["0","0","0"]], expected: 0, name: "3x3 All Zeros"),
    TestCase(matrix: [["1","0"],["0","1"]], expected: 1, name: "2x2 Diagonal Ones"),
    TestCase(matrix: [["1","1","1","1","1"],["1","1","1","1","1"],["1","1","1","1","1"],["1","1","1","1","1"],["1","1","1","1","1"]], expected: 25, name: "5x5 All Ones"),
    TestCase(matrix: [["1","1"],["1","1"]], expected: 4, name: "2x2 Matrix Pattern 16"),
    TestCase(matrix: [["0","0","0"],["0","0","0"],["0","0","0"]], expected: 0, name: "3x3 Matrix Pattern 17"),
    TestCase(matrix: [["1","1","1","1"],["1","1","1","1"],["1","1","1","1"],["1","1","1","1"]], expected: 16, name: "4x4 Matrix Pattern 18"),
    TestCase(matrix: [["0","0","0","0","0"],["0","0","0","0","0"],["0","0","0","0","0"],["0","0","0","0","0"],["0","0","0","0","0"]], expected: 0, name: "5x5 Matrix Pattern 19"),
    TestCase(matrix: [["1","1","1","1","1","1"],["1","1","1","1","1","1"],["1","1","1","1","1","1"],["1","1","1","1","1","1"],["1","1","1","1","1","1"],["1","1","1","1","1","1"]], expected: 36, name: "6x6 Matrix Pattern 20"),
    TestCase(matrix: [["0","0"],["0","0"]], expected: 0, name: "2x2 Matrix Pattern 21"),
    TestCase(matrix: [["1","1","1"],["1","1","1"],["1","1","1"]], expected: 9, name: "3x3 Matrix Pattern 22"),
    TestCase(matrix: [["0","0","0","0"],["0","0","0","0"],["0","0","0","0"],["0","0","0","0"]], expected: 0, name: "4x4 Matrix Pattern 23"),
    TestCase(matrix: [["1","1","1","1","1"],["1","1","1","1","1"],["1","1","1","1","1"],["1","1","1","1","1"],["1","1","1","1","1"]], expected: 25, name: "5x5 Matrix Pattern 24"),
    TestCase(matrix: [["0","0","0","0","0","0"],["0","0","0","0","0","0"],["0","0","0","0","0","0"],["0","0","0","0","0","0"],["0","0","0","0","0","0"],["0","0","0","0","0","0"]], expected: 0, name: "6x6 Matrix Pattern 25"),
    TestCase(matrix: [["1","1"],["1","1"]], expected: 4, name: "2x2 Matrix Pattern 26"),
    TestCase(matrix: [["0","0","0"],["0","0","0"],["0","0","0"]], expected: 0, name: "3x3 Matrix Pattern 27"),
    TestCase(matrix: [["1","1","1","1"],["1","1","1","1"],["1","1","1","1"],["1","1","1","1"]], expected: 16, name: "4x4 Matrix Pattern 28"),
    TestCase(matrix: [["0","0","0","0","0"],["0","0","0","0","0"],["0","0","0","0","0"],["0","0","0","0","0"],["0","0","0","0","0"]], expected: 0, name: "5x5 Matrix Pattern 29"),
    TestCase(matrix: [["1","1","1","1","1","1"],["1","1","1","1","1","1"],["1","1","1","1","1","1"],["1","1","1","1","1","1"],["1","1","1","1","1","1"],["1","1","1","1","1","1"]], expected: 36, name: "6x6 Matrix Pattern 30"),
    TestCase(matrix: [["0","0"],["0","0"]], expected: 0, name: "2x2 Matrix Pattern 31"),
    TestCase(matrix: [["1","1","1"],["1","1","1"],["1","1","1"]], expected: 9, name: "3x3 Matrix Pattern 32"),
    TestCase(matrix: [["0","0","0","0"],["0","0","0","0"],["0","0","0","0"],["0","0","0","0"]], expected: 0, name: "4x4 Matrix Pattern 33"),
    TestCase(matrix: [["1","1","1","1","1"],["1","1","1","1","1"],["1","1","1","1","1"],["1","1","1","1","1"],["1","1","1","1","1"]], expected: 25, name: "5x5 Matrix Pattern 34"),
    TestCase(matrix: [["0","0","0","0","0","0"],["0","0","0","0","0","0"],["0","0","0","0","0","0"],["0","0","0","0","0","0"],["0","0","0","0","0","0"],["0","0","0","0","0","0"]], expected: 0, name: "6x6 Matrix Pattern 35"),
    TestCase(matrix: [["1","1"],["1","1"]], expected: 4, name: "2x2 Matrix Pattern 36"),
    TestCase(matrix: [["0","0","0"],["0","0","0"],["0","0","0"]], expected: 0, name: "3x3 Matrix Pattern 37"),
    TestCase(matrix: [["1","1","1","1"],["1","1","1","1"],["1","1","1","1"],["1","1","1","1"]], expected: 16, name: "4x4 Matrix Pattern 38"),
    TestCase(matrix: [["0","0","0","0","0"],["0","0","0","0","0"],["0","0","0","0","0"],["0","0","0","0","0"],["0","0","0","0","0"]], expected: 0, name: "5x5 Matrix Pattern 39"),
    TestCase(matrix: [["1","1","1","1","1","1"],["1","1","1","1","1","1"],["1","1","1","1","1","1"],["1","1","1","1","1","1"],["1","1","1","1","1","1"],["1","1","1","1","1","1"]], expected: 36, name: "6x6 Matrix Pattern 40"),
    TestCase(matrix: [["0","0"],["0","0"]], expected: 0, name: "2x2 Matrix Pattern 41"),
    TestCase(matrix: [["1","1","1"],["1","1","1"],["1","1","1"]], expected: 9, name: "3x3 Matrix Pattern 42"),
    TestCase(matrix: [["0","0","0","0"],["0","0","0","0"],["0","0","0","0"],["0","0","0","0"]], expected: 0, name: "4x4 Matrix Pattern 43"),
    TestCase(matrix: [["1","1","1","1","1"],["1","1","1","1","1"],["1","1","1","1","1"],["1","1","1","1","1"],["1","1","1","1","1"]], expected: 25, name: "5x5 Matrix Pattern 44"),
    TestCase(matrix: [["0","0","0","0","0","0"],["0","0","0","0","0","0"],["0","0","0","0","0","0"],["0","0","0","0","0","0"],["0","0","0","0","0","0"],["0","0","0","0","0","0"]], expected: 0, name: "6x6 Matrix Pattern 45"),
    TestCase(matrix: [["1","1"],["1","1"]], expected: 4, name: "2x2 Matrix Pattern 46"),
    TestCase(matrix: [["0","0","0"],["0","0","0"],["0","0","0"]], expected: 0, name: "3x3 Matrix Pattern 47"),
    TestCase(matrix: [["1","1","1","1"],["1","1","1","1"],["1","1","1","1"],["1","1","1","1"]], expected: 16, name: "4x4 Matrix Pattern 48"),
    TestCase(matrix: [["0","0","0","0","0"],["0","0","0","0","0"],["0","0","0","0","0"],["0","0","0","0","0"],["0","0","0","0","0"]], expected: 0, name: "5x5 Matrix Pattern 49"),
    TestCase(matrix: [["1","1","1","1","1","1"],["1","1","1","1","1","1"],["1","1","1","1","1","1"],["1","1","1","1","1","1"],["1","1","1","1","1","1"],["1","1","1","1","1","1"]], expected: 36, name: "6x6 Matrix Pattern 50")
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
    TestCase(n: 1, expected: 1, name: "n = 1"),
    TestCase(n: 2, expected: 2, name: "n = 2"),
    TestCase(n: 3, expected: 3, name: "n = 3"),
    TestCase(n: 4, expected: 5, name: "n = 4"),
    TestCase(n: 5, expected: 8, name: "n = 5"),
    TestCase(n: 6, expected: 13, name: "n = 6"),
    TestCase(n: 7, expected: 21, name: "n = 7"),
    TestCase(n: 8, expected: 34, name: "n = 8"),
    TestCase(n: 9, expected: 55, name: "n = 9"),
    TestCase(n: 10, expected: 89, name: "n = 10"),
    TestCase(n: 11, expected: 144, name: "n = 11"),
    TestCase(n: 12, expected: 233, name: "n = 12"),
    TestCase(n: 13, expected: 377, name: "n = 13"),
    TestCase(n: 14, expected: 610, name: "n = 14"),
    TestCase(n: 15, expected: 987, name: "n = 15"),
    TestCase(n: 16, expected: 1597, name: "n = 16"),
    TestCase(n: 17, expected: 2584, name: "n = 17"),
    TestCase(n: 18, expected: 4181, name: "n = 18"),
    TestCase(n: 19, expected: 6765, name: "n = 19"),
    TestCase(n: 20, expected: 10946, name: "n = 20"),
    TestCase(n: 21, expected: 17711, name: "n = 21"),
    TestCase(n: 22, expected: 28657, name: "n = 22"),
    TestCase(n: 23, expected: 46368, name: "n = 23"),
    TestCase(n: 24, expected: 75025, name: "n = 24"),
    TestCase(n: 25, expected: 121393, name: "n = 25"),
    TestCase(n: 26, expected: 196418, name: "n = 26"),
    TestCase(n: 27, expected: 317811, name: "n = 27"),
    TestCase(n: 28, expected: 514229, name: "n = 28"),
    TestCase(n: 29, expected: 832040, name: "n = 29"),
    TestCase(n: 30, expected: 1346269, name: "n = 30"),
    TestCase(n: 31, expected: 2178309, name: "n = 31"),
    TestCase(n: 32, expected: 3524578, name: "n = 32"),
    TestCase(n: 33, expected: 5702887, name: "n = 33"),
    TestCase(n: 34, expected: 9227465, name: "n = 34"),
    TestCase(n: 35, expected: 14930352, name: "n = 35"),
    TestCase(n: 36, expected: 24157817, name: "n = 36"),
    TestCase(n: 37, expected: 39088169, name: "n = 37"),
    TestCase(n: 38, expected: 63245986, name: "n = 38"),
    TestCase(n: 39, expected: 102334155, name: "n = 39"),
    TestCase(n: 40, expected: 165580141, name: "n = 40"),
    TestCase(n: 41, expected: 267914296, name: "n = 41"),
    TestCase(n: 42, expected: 433494437, name: "n = 42"),
    TestCase(n: 43, expected: 701408733, name: "n = 43"),
    TestCase(n: 44, expected: 1134903170, name: "n = 44"),
    TestCase(n: 45, expected: 1836311903, name: "n = 45"),
    TestCase(n: 46, expected: 2971215073, name: "n = 46"),
    TestCase(n: 47, expected: 4807526976, name: "n = 47"),
    TestCase(n: 48, expected: 7778742049, name: "n = 48"),
    TestCase(n: 49, expected: 12586269025, name: "n = 49"),
    TestCase(n: 50, expected: 20365011074, name: "n = 50")
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
    TestCase(price: [0, 1, 5, 8, 9, 10, 17, 17, 20], expected: 22, name: "Example 1 (Lengths 2 & 6 -> 5+17=22)"),
    TestCase(price: [0, 3, 5, 8, 9, 10, 17, 17, 20], expected: 24, name: "Example 2 (8 cuts of length 1 -> 8*3=24)"),
    TestCase(price: [0, 3], expected: 3, name: "Example 3 (Single length 1 rod)"),
    TestCase(price: [0, 1, 1, 1, 100], expected: 100, name: "Single Full Piece Optimal"),
    TestCase(price: [0, 0, 0, 0], expected: 0, name: "All Zero Prices"),
    TestCase(price: [0], expected: 0, name: "Zero Length Rod"),
    TestCase(price: [0, 2, 5, 9, 10, 15, 17, 20, 24, 30], expected: 30, name: "Length 9 Rod"),
    TestCase(price: [0, 2, 2, 2, 2, 2], expected: 10, name: "Uniform Price per Unit Length"),
    TestCase(price: [0, 1, 6, 7, 11], expected: 12, name: "Length 4 Rod (2x length 2)"),
    TestCase(price: [0, 4, 4, 4, 4, 4], expected: 20, name: "5 Cuts of Length 1"),
    TestCase(price: [0, 1, 5, 8, 9, 10, 17, 17, 20, 24, 30], expected: 30, name: "Length 10 Rod"),
    TestCase(price: [0, 10], expected: 10, name: "Single Length 1 Piece"),
    TestCase(price: [0, 5, 5, 5, 5], expected: 20, name: "4 Cuts of Length 1"),
    TestCase(price: [0, 2, 5, 7, 8, 10], expected: 12, name: "Length 5 Rod (Lengths 2 & 3)"),
    TestCase(price: [0, 1, 5, 8, 9, 10, 17, 17, 20, 24, 30, 35, 40], expected: 40, name: "Length 12 Rod"),
    TestCase(price: [0, 2, 4], expected: 4, name: "Rod Length 2 Config 16"),
    TestCase(price: [0, 3, 5, 7], expected: 9, name: "Rod Length 3 Config 17"),
    TestCase(price: [0, 4, 6, 8, 10], expected: 16, name: "Rod Length 4 Config 18"),
    TestCase(price: [0, 5, 7, 9, 11, 13], expected: 25, name: "Rod Length 5 Config 19"),
    TestCase(price: [0, 2, 4, 6, 8, 10, 12], expected: 12, name: "Rod Length 6 Config 20"),
    TestCase(price: [0, 3, 5, 7, 9, 11, 13, 15], expected: 21, name: "Rod Length 7 Config 21"),
    TestCase(price: [0, 4, 6, 8, 10, 12, 14, 16, 18], expected: 32, name: "Rod Length 8 Config 22"),
    TestCase(price: [0, 5, 7, 9, 11, 13, 15, 17, 19, 21], expected: 45, name: "Rod Length 9 Config 23"),
    TestCase(price: [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20], expected: 20, name: "Rod Length 10 Config 24"),
    TestCase(price: [0, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23], expected: 33, name: "Rod Length 11 Config 25"),
    TestCase(price: [0, 4, 6], expected: 8, name: "Rod Length 2 Config 26"),
    TestCase(price: [0, 5, 7, 9], expected: 15, name: "Rod Length 3 Config 27"),
    TestCase(price: [0, 2, 4, 6, 8], expected: 8, name: "Rod Length 4 Config 28"),
    TestCase(price: [0, 3, 5, 7, 9, 11], expected: 15, name: "Rod Length 5 Config 29"),
    TestCase(price: [0, 4, 6, 8, 10, 12, 14], expected: 24, name: "Rod Length 6 Config 30"),
    TestCase(price: [0, 5, 7, 9, 11, 13, 15, 17], expected: 35, name: "Rod Length 7 Config 31"),
    TestCase(price: [0, 2, 4, 6, 8, 10, 12, 14, 16], expected: 16, name: "Rod Length 8 Config 32"),
    TestCase(price: [0, 3, 5, 7, 9, 11, 13, 15, 17, 19], expected: 27, name: "Rod Length 9 Config 33"),
    TestCase(price: [0, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22], expected: 40, name: "Rod Length 10 Config 34"),
    TestCase(price: [0, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25], expected: 55, name: "Rod Length 11 Config 35"),
    TestCase(price: [0, 2, 4], expected: 4, name: "Rod Length 2 Config 36"),
    TestCase(price: [0, 3, 5, 7], expected: 9, name: "Rod Length 3 Config 37"),
    TestCase(price: [0, 4, 6, 8, 10], expected: 16, name: "Rod Length 4 Config 38"),
    TestCase(price: [0, 5, 7, 9, 11, 13], expected: 25, name: "Rod Length 5 Config 39"),
    TestCase(price: [0, 2, 4, 6, 8, 10, 12], expected: 12, name: "Rod Length 6 Config 40"),
    TestCase(price: [0, 3, 5, 7, 9, 11, 13, 15], expected: 21, name: "Rod Length 7 Config 41"),
    TestCase(price: [0, 4, 6, 8, 10, 12, 14, 16, 18], expected: 32, name: "Rod Length 8 Config 42"),
    TestCase(price: [0, 5, 7, 9, 11, 13, 15, 17, 19, 21], expected: 45, name: "Rod Length 9 Config 43"),
    TestCase(price: [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20], expected: 20, name: "Rod Length 10 Config 44"),
    TestCase(price: [0, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23], expected: 33, name: "Rod Length 11 Config 45"),
    TestCase(price: [0, 4, 6], expected: 8, name: "Rod Length 2 Config 46"),
    TestCase(price: [0, 5, 7, 9], expected: 15, name: "Rod Length 3 Config 47"),
    TestCase(price: [0, 2, 4, 6, 8], expected: 8, name: "Rod Length 4 Config 48"),
    TestCase(price: [0, 3, 5, 7, 9, 11], expected: 15, name: "Rod Length 5 Config 49"),
    TestCase(price: [0, 4, 6, 8, 10, 12, 14], expected: 24, name: "Rod Length 6 Config 50")
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
