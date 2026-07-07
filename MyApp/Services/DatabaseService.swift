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
""",
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
""",
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
            ),
            Question(
                id: "max_vowels_substring",
                title: "Maximum Vowels in a Substring of Given Length",
                category: "dsa",
                difficulty: "Medium",
                topics: ["String", "Sliding Window"],
                description: "Given a string s and an integer k, return the maximum number of vowel letters ('a', 'e', 'i', 'o', 'u') in any substring of s with length k.",
                templateCode: """
class Solution {
    func maxVowels(_ s: String, _ k: Int) -> Int {
        // TODO: Write your solution here
        return 0
    }
}
""",
                solutionCode: """
class Solution {
    func maxVowels(_ s: String, _ k: Int) -> Int {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        let chars = Array(s)
        var count = 0
        for i in 0..<k {
            if vowels.contains(chars[i]) {
                count += 1
            }
        }
        var maxCount = count
        for i in k..<chars.count {
            if vowels.contains(chars[i]) {
                count += 1
            }
            if vowels.contains(chars[i - k]) {
                count -= 1
            }
            maxCount = max(maxCount, count)
        }
        return maxCount
    }
}
""",
                testHarness: """
let solution = Solution()
struct TestCase {
    let s: String
    let k: Int
    let expected: Int
    let name: String
}
let testCases = [
    TestCase(s: "abciiidef", k: 3, expected: 3, name: "Example 1 (window of iii)"),
    TestCase(s: "aeiou", k: 2, expected: 2, name: "Example 2 (all vowels)"),
    TestCase(s: "leetcode", k: 3, expected: 2, name: "Example 3 (leetcode, k=3)"),
    TestCase(s: "rhythms", k: 4, expected: 0, name: "No Vowels At All"),
    TestCase(s: "tryhard", k: 4, expected: 1, name: "Single Vowel Window"),
    TestCase(s: "aaaaa", k: 1, expected: 1, name: "Single Char Window All Vowels"),
    TestCase(s: "bcdaeiou", k: 8, expected: 5, name: "Whole String Window"),
    TestCase(s: "bcdfg", k: 5, expected: 0, name: "No Vowels Whole Window")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = solution.maxVowels(tc.s, tc.k)
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
                id: "segregate_zeroes_ones",
                title: "Segregate 0s and 1s in an Array",
                category: "dsa",
                difficulty: "Easy",
                topics: ["Array", "Two Pointers"],
                description: "Given an array containing only 0s and 1s, rearrange it in-place so that all the 0s appear before all the 1s, and return the rearranged array.",
                templateCode: """
class Solution {
    func segregate(_ nums: [Int]) -> [Int] {
        // TODO: Write your solution here
        return nums
    }
}
""",
                solutionCode: """
class Solution {
    func segregate(_ nums: [Int]) -> [Int] {
        var result = nums
        var left = 0
        var right = result.count - 1
        while left < right {
            if result[left] == 0 {
                left += 1
            } else if result[right] == 1 {
                right -= 1
            } else {
                result.swapAt(left, right)
                left += 1
                right -= 1
            }
        }
        return result
    }
}
""",
                testHarness: """
let solution = Solution()
struct TestCase {
    let nums: [Int]
    let expected: [Int]
    let name: String
}
let testCases = [
    TestCase(nums: [0, 1, 0, 1, 1, 0], expected: [0, 0, 0, 1, 1, 1], name: "Example 1 (Mixed 3 zeros, 3 ones)"),
    TestCase(nums: [1, 1, 1], expected: [1, 1, 1], name: "All Ones"),
    TestCase(nums: [0, 0, 0], expected: [0, 0, 0], name: "All Zeros"),
    TestCase(nums: [1, 0], expected: [0, 1], name: "Two Elements Swapped"),
    TestCase(nums: [0], expected: [0], name: "Single Zero"),
    TestCase(nums: [1], expected: [1], name: "Single One"),
    TestCase(nums: [0, 1, 0, 1, 0, 1, 0, 1], expected: [0, 0, 0, 0, 1, 1, 1, 1], name: "Alternating 4 and 4"),
    TestCase(nums: [1, 0, 1, 0, 1, 0, 1, 0, 1, 0], expected: [0, 0, 0, 0, 0, 1, 1, 1, 1, 1], name: "Alternating 5 and 5")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = solution.segregate(tc.nums)
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
                id: "leftmost_column_one",
                title: "Leftmost Column with at Least a One",
                category: "dsa",
                difficulty: "Medium",
                topics: ["Binary Search", "Matrix"],
                description: "Given a rows x cols binary matrix where each row is sorted in non-decreasing order, return the index of the leftmost column that contains at least one 1. If no such column exists, return -1.",
                templateCode: """
class Solution {
    func leftMostColumnWithOne(_ matrix: [[Int]]) -> Int {
        // TODO: Write your solution here
        return -1
    }
}
""",
                solutionCode: """
class Solution {
    func leftMostColumnWithOne(_ matrix: [[Int]]) -> Int {
        guard !matrix.isEmpty, !matrix[0].isEmpty else { return -1 }
        let rows = matrix.count
        let cols = matrix[0].count
        var row = 0
        var col = cols - 1
        var result = -1
        while row < rows && col >= 0 {
            if matrix[row][col] == 1 {
                result = col
                col -= 1
            } else {
                row += 1
            }
        }
        return result
    }
}
""",
                testHarness: """
let solution = Solution()
struct TestCase {
    let matrix: [[Int]]
    let expected: Int
    let name: String
}
let testCases = [
    TestCase(matrix: [[0, 0, 0, 1], [0, 0, 1, 1], [0, 1, 1, 1]], expected: 1, name: "Example 1 (Staircase Matrix)"),
    TestCase(matrix: [[0, 0], [0, 0]], expected: -1, name: "No Ones Anywhere"),
    TestCase(matrix: [[1]], expected: 0, name: "Single Cell One"),
    TestCase(matrix: [[0]], expected: -1, name: "Single Cell Zero"),
    TestCase(matrix: [[0, 0, 0], [0, 0, 0], [0, 0, 1]], expected: 2, name: "One Only In Last Row/Col"),
    TestCase(matrix: [[1, 1, 1], [1, 1, 1], [1, 1, 1]], expected: 0, name: "All Ones"),
    TestCase(matrix: [[0, 1], [0, 1], [0, 1]], expected: 1, name: "Second Column All Ones"),
    TestCase(matrix: [[0, 0, 1, 1], [0, 1, 1, 1], [1, 1, 1, 1], [0, 0, 0, 1]], expected: 0, name: "Leading One In Third Row")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = solution.leftMostColumnWithOne(tc.matrix)
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
                id: "group_anagrams",
                title: "Group Anagrams",
                category: "dsa",
                difficulty: "Medium",
                topics: ["Array", "Hash Table", "String"],
                description: "Given an array of strings, group the anagrams together. Two strings are anagrams if one can be formed by rearranging the letters of the other.",
                templateCode: """
class Solution {
    func groupAnagrams(_ strs: [String]) -> [[String]] {
        // TODO: Write your solution here
        return []
    }
}
""",
                solutionCode: """
class Solution {
    func groupAnagrams(_ strs: [String]) -> [[String]] {
        var groups: [String: [String]] = [:]
        for s in strs {
            let key = String(s.sorted())
            groups[key, default: []].append(s)
        }
        var result: [[String]] = []
        for (_, group) in groups {
            result.append(group.sorted())
        }
        return result.sorted { $0[0] < $1[0] }
    }
}
""",
                testHarness: """
let solution = Solution()
struct TestCase {
    let strs: [String]
    let expected: [[String]]
    let name: String
}
func formatGroups(_ groups: [[String]]) -> String {
    return groups.map { "[" + $0.joined(separator: ",") + "]" }.joined()
}
let testCases = [
    TestCase(strs: ["eat", "tea", "tan", "ate", "nat", "bat"], expected: [["ate", "eat", "tea"], ["bat"], ["nat", "tan"]], name: "Example 1 (Mixed Anagrams)"),
    TestCase(strs: [""], expected: [[""]], name: "Single Empty String"),
    TestCase(strs: ["a"], expected: [["a"]], name: "Single Character"),
    TestCase(strs: ["abc", "bca", "cab", "xyz"], expected: [["abc", "bca", "cab"], ["xyz"]], name: "Three-Way Anagram Group"),
    TestCase(strs: ["abc", "def"], expected: [["abc"], ["def"]], name: "No Anagrams"),
    TestCase(strs: ["ab", "ba", "ab"], expected: [["ab", "ab", "ba"]], name: "Duplicate Strings"),
    TestCase(strs: ["listen", "silent", "enlist", "google", "gooogle"], expected: [["enlist", "listen", "silent"], ["google"], ["gooogle"]], name: "Different Lengths Not Grouped")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = solution.groupAnagrams(tc.strs)
    let endTime = DispatchTime.now()
    let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
    let timeInterval = Double(nanoTime) / 1_000_000.0
    let resultStr = formatGroups(result)
    let expectedStr = formatGroups(tc.expected)
    if resultStr == expectedStr {
        print("CASE \\(index) | PASS | Name: \\(tc.name) | Output: \\(resultStr) | Expected: \\(expectedStr) | Time: \\(String(format: "%.3f", timeInterval))ms")
        passedCount += 1
    } else {
        print("CASE \\(index) | FAIL | Name: \\(tc.name) | Output: \\(resultStr) | Expected: \\(expectedStr) | Time: \\(String(format: "%.3f", timeInterval))ms")
    }
}
print("SUMMARY | \\(passedCount)/\\(testCases.count) PASSED")
print("---DSA_TEST_RESULTS_END---")
"""
            ),
            Question(
                id: "longest_substring_no_repeat",
                title: "Longest Substring Without Repeating Characters",
                category: "dsa",
                difficulty: "Medium",
                topics: ["String", "Sliding Window", "Hash Table"],
                description: "Given a string s, find the length of the longest substring without repeating characters.",
                templateCode: """
class Solution {
    func lengthOfLongestSubstring(_ s: String) -> Int {
        // TODO: Write your solution here
        return 0
    }
}
""",
                solutionCode: """
class Solution {
    func lengthOfLongestSubstring(_ s: String) -> Int {
        var lastSeen: [Character: Int] = [:]
        var start = 0
        var maxLen = 0
        let chars = Array(s)
        for i in 0..<chars.count {
            if let seenIndex = lastSeen[chars[i]], seenIndex >= start {
                start = seenIndex + 1
            }
            lastSeen[chars[i]] = i
            maxLen = max(maxLen, i - start + 1)
        }
        return maxLen
    }
}
""",
                testHarness: """
let solution = Solution()
struct TestCase {
    let s: String
    let expected: Int
    let name: String
}
let testCases = [
    TestCase(s: "abcabcbb", expected: 3, name: "Example 1 (abcabcbb)"),
    TestCase(s: "bbbbb", expected: 1, name: "Example 2 (All Same Char)"),
    TestCase(s: "pwwkew", expected: 3, name: "Example 3 (pwwkew)"),
    TestCase(s: "", expected: 0, name: "Empty String"),
    TestCase(s: " ", expected: 1, name: "Single Space"),
    TestCase(s: "au", expected: 2, name: "Two Distinct Chars"),
    TestCase(s: "dvdf", expected: 3, name: "Repeat Mid-Window (dvdf)"),
    TestCase(s: "abba", expected: 2, name: "Palindromic Repeat (abba)")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = solution.lengthOfLongestSubstring(tc.s)
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
                id: "next_greater_element",
                title: "Next Greater Element",
                category: "dsa",
                difficulty: "Medium",
                topics: ["Array", "Stack", "Monotonic Stack"],
                description: "Given an array of integers, find the first greater element to the right of each element. If no greater element exists to the right, use -1 for that position.",
                templateCode: """
class Solution {
    func nextGreaterElements(_ nums: [Int]) -> [Int] {
        // TODO: Write your solution here
        return []
    }
}
""",
                solutionCode: """
class Solution {
    func nextGreaterElements(_ nums: [Int]) -> [Int] {
        var result = Array(repeating: -1, count: nums.count)
        var stack: [Int] = []
        for i in 0..<nums.count {
            while let last = stack.last, nums[last] < nums[i] {
                result[last] = nums[i]
                stack.removeLast()
            }
            stack.append(i)
        }
        return result
    }
}
""",
                testHarness: """
let solution = Solution()
struct TestCase {
    let nums: [Int]
    let expected: [Int]
    let name: String
}
let testCases = [
    TestCase(nums: [4, 5, 2, 10, 8], expected: [5, 10, 10, -1, -1], name: "Example 1 (4,5,2,10,8)"),
    TestCase(nums: [1, 2, 3, 4, 5], expected: [2, 3, 4, 5, -1], name: "Strictly Increasing"),
    TestCase(nums: [5, 4, 3, 2, 1], expected: [-1, -1, -1, -1, -1], name: "Strictly Decreasing"),
    TestCase(nums: [2, 2, 2], expected: [-1, -1, -1], name: "All Equal"),
    TestCase(nums: [1], expected: [-1], name: "Single Element"),
    TestCase(nums: [3, 8, 4, 1, 2], expected: [8, -1, -1, 2, -1], name: "Mixed Values"),
    TestCase(nums: [1, 3, 2, 4], expected: [3, 4, 4, -1], name: "Two Pops Chain"),
    TestCase(nums: [6, 5, 4, 3, 2, 1, 7], expected: [7, 7, 7, 7, 7, 7, -1], name: "Big Jump At End")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = solution.nextGreaterElements(tc.nums)
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
                id: "todo_command_processor",
                title: "Task Command Processor",
                category: "dsa",
                difficulty: "Medium",
                topics: ["Simulation", "Array", "String Parsing"],
                description: "Design a task management system that processes a series of commands: ADD Title, REMOVE TaskNumber, MARK TaskNumber, and LIST (all 1-based indices). Return the output lines produced. Invalid or out-of-range REMOVE/MARK commands must produce a descriptive error line instead of crashing.",
                templateCode: """
class Solution {
    func manageToDoList(_ commands: [String]) -> [String] {
        // TODO: Write your solution here
        return []
    }
}
""",
                solutionCode: """
class Solution {
    func manageToDoList(_ commands: [String]) -> [String] {
        var titles: [String] = []
        var completed: [Bool] = []
        var output: [String] = []

        for command in commands {
            let parts = command.components(separatedBy: " ")
            guard let action = parts.first else {
                output.append("Error: Invalid command.")
                continue
            }

            switch action {
            case "ADD":
                let title = parts.dropFirst().joined(separator: " ")
                titles.append(title)
                completed.append(false)
            case "REMOVE":
                guard parts.count == 2, let idx = Int(parts[1]) else {
                    output.append("Error: Invalid REMOVE command.")
                    continue
                }
                if idx < 1 || idx > titles.count {
                    output.append("Error: Task number \\(idx) does not exist.")
                } else {
                    titles.remove(at: idx - 1)
                    completed.remove(at: idx - 1)
                }
            case "MARK":
                guard parts.count == 2, let idx = Int(parts[1]) else {
                    output.append("Error: Invalid MARK command.")
                    continue
                }
                if idx < 1 || idx > titles.count {
                    output.append("Error: Task number \\(idx) does not exist.")
                } else {
                    completed[idx - 1] = true
                }
            case "LIST":
                for i in 0..<titles.count {
                    let mark = completed[i] ? "✓" : " "
                    output.append("\\(i + 1). [\\(mark)] \\(titles[i])")
                }
            default:
                output.append("Error: Invalid command.")
            }
        }

        return output
    }
}
""",
                testHarness: """
let solution = Solution()
struct TestCase {
    let commands: [String]
    let expected: [String]
    let name: String
}
func formatLines(_ lines: [String]) -> String {
    return lines.joined(separator: " || ")
}
let testCases = [
    TestCase(commands: ["ADD Buy groceries", "ADD Walk the dog", "MARK 1", "LIST"], expected: ["1. [✓] Buy groceries", "2. [ ] Walk the dog"], name: "Example 1 (Add, Mark, List)"),
    TestCase(commands: ["ADD Finish homework", "REMOVE 2"], expected: ["Error: Task number 2 does not exist."], name: "Example 2 (Remove Out of Range)"),
    TestCase(commands: ["REMOVE 1"], expected: ["Error: Task number 1 does not exist."], name: "Remove Before Any Add"),
    TestCase(commands: ["MARK abc"], expected: ["Error: Invalid MARK command."], name: "Mark Non-Numeric"),
    TestCase(commands: ["REMOVE"], expected: ["Error: Invalid REMOVE command."], name: "Remove Missing Argument"),
    TestCase(commands: ["FOO 1"], expected: ["Error: Invalid command."], name: "Unrecognized Command"),
    TestCase(commands: ["ADD Task A", "ADD Task B", "ADD Task C", "REMOVE 2", "LIST"], expected: ["1. [ ] Task A", "2. [ ] Task C"], name: "Remove Middle Then List"),
    TestCase(commands: ["ADD X", "MARK 1", "MARK 1", "LIST"], expected: ["1. [✓] X"], name: "Mark Same Task Twice")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = solution.manageToDoList(tc.commands)
    let endTime = DispatchTime.now()
    let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
    let timeInterval = Double(nanoTime) / 1_000_000.0
    let resultStr = formatLines(result)
    let expectedStr = formatLines(tc.expected)
    if resultStr == expectedStr {
        print("CASE \\(index) | PASS | Name: \\(tc.name) | Output: \\(resultStr) | Expected: \\(expectedStr) | Time: \\(String(format: "%.3f", timeInterval))ms")
        passedCount += 1
    } else {
        print("CASE \\(index) | FAIL | Name: \\(tc.name) | Output: \\(resultStr) | Expected: \\(expectedStr) | Time: \\(String(format: "%.3f", timeInterval))ms")
    }
}
print("SUMMARY | \\(passedCount)/\\(testCases.count) PASSED")
print("---DSA_TEST_RESULTS_END---")
"""
            ),
            Question(
                id: "online_store_inventory",
                title: "Online Store Inventory & Purchases",
                category: "dsa",
                difficulty: "Medium",
                topics: ["Hash Table", "Simulation"],
                description: "Given parallel arrays of product names/prices (the inventory) and product names/quantities purchased, compute the total cost of all purchases, ignoring purchases of products that are not in the inventory. Round the result to two decimal places.",
                templateCode: """
class Solution {
    func calculateTotalPrice(_ productNames: [String], _ productPrices: [Double], _ purchaseNames: [String], _ purchaseQuantities: [Int]) -> Double {
        // TODO: Write your solution here
        return 0.0
    }
}
""",
                solutionCode: """
class Solution {
    func calculateTotalPrice(_ productNames: [String], _ productPrices: [Double], _ purchaseNames: [String], _ purchaseQuantities: [Int]) -> Double {
        var inventory: [String: Double] = [:]
        for i in 0..<productNames.count {
            inventory[productNames[i]] = productPrices[i]
        }
        var total: Double = 0
        for i in 0..<purchaseNames.count {
            if let price = inventory[purchaseNames[i]] {
                total += price * Double(purchaseQuantities[i])
            }
        }
        return (total * 100).rounded() / 100
    }
}
""",
                testHarness: """
let solution = Solution()
struct TestCase {
    let productNames: [String]
    let productPrices: [Double]
    let purchaseNames: [String]
    let purchaseQuantities: [Int]
    let expected: Double
    let name: String
}
let testCases = [
    TestCase(productNames: ["Apple", "Banana", "Cherry"], productPrices: [2.5, 1.0, 3.0], purchaseNames: ["Apple", "Cherry", "Banana"], purchaseQuantities: [3, 2, 1], expected: 14.5, name: "Example 1 (Fruit Basket)"),
    TestCase(productNames: ["Laptop", "Mouse", "Keyboard"], productPrices: [1000.0, 25.0, 45.0], purchaseNames: ["Laptop", "Mouse", "Keyboard"], purchaseQuantities: [1, 2, 1], expected: 1095.0, name: "Example 2 (Electronics)"),
    TestCase(productNames: ["Pen"], productPrices: [0.99], purchaseNames: ["Pen"], purchaseQuantities: [10], expected: 9.9, name: "Fractional Unit Price"),
    TestCase(productNames: ["Widget"], productPrices: [5.0], purchaseNames: ["Gadget"], purchaseQuantities: [3], expected: 0.0, name: "Purchase Not In Inventory"),
    TestCase(productNames: ["A", "B"], productPrices: [1.11, 2.22], purchaseNames: ["A", "B", "A"], purchaseQuantities: [1, 1, 1], expected: 4.44, name: "Repeated Purchase Of Same Product"),
    TestCase(productNames: [], productPrices: [], purchaseNames: ["X"], purchaseQuantities: [5], expected: 0.0, name: "Empty Inventory"),
    TestCase(productNames: ["Item"], productPrices: [3.333], purchaseNames: ["Item"], purchaseQuantities: [3], expected: 10.0, name: "Rounding To Nearest Cent"),
    TestCase(productNames: ["X", "Y", "Z"], productPrices: [10.0, 20.0, 30.0], purchaseNames: [], purchaseQuantities: [], expected: 0.0, name: "No Purchases Made")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = solution.calculateTotalPrice(tc.productNames, tc.productPrices, tc.purchaseNames, tc.purchaseQuantities)
    let endTime = DispatchTime.now()
    let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
    let timeInterval = Double(nanoTime) / 1_000_000.0
    let passed = abs(result - tc.expected) < 0.001
    let resultStr = String(format: "%.2f", result)
    let expectedStr = String(format: "%.2f", tc.expected)
    if passed {
        print("CASE \\(index) | PASS | Name: \\(tc.name) | Output: \\(resultStr) | Expected: \\(expectedStr) | Time: \\(String(format: "%.3f", timeInterval))ms")
        passedCount += 1
    } else {
        print("CASE \\(index) | FAIL | Name: \\(tc.name) | Output: \\(resultStr) | Expected: \\(expectedStr) | Time: \\(String(format: "%.3f", timeInterval))ms")
    }
}
print("SUMMARY | \\(passedCount)/\\(testCases.count) PASSED")
print("---DSA_TEST_RESULTS_END---")
"""
            ),
            Question(
                id: "lru_cache_design",
                title: "Design and Implement an LRU Cache",
                category: "dsa",
                difficulty: "Hard",
                topics: ["LRU", "Cache Design", "Hash Table", "Linked List", "System Design"],
                description: """
Design a data structure that implements a Least Recently Used (LRU) cache. It must support get and put in O(1) average time complexity.

Implement the LRUCache class:
- LRUCache(_ capacity: Int) initializes the cache with a positive size capacity.
- func get(_ key: Int) -> Int returns the value of the key if it exists, otherwise -1. Accessing a key counts as "using" it.
- func put(_ key: Int, _ value: Int) updates the value of the key if it exists, or inserts the key-value pair if it doesn't. If inserting a new key would exceed capacity, evict the least recently used key first.

Example:
cache = LRUCache(2)
cache.put(1, 1)
cache.put(2, 2)
cache.get(1)       // returns 1
cache.put(3, 3)    // evicts key 2 (least recently used)
cache.get(2)       // returns -1 (not found)
cache.put(4, 4)    // evicts key 1
cache.get(1)       // returns -1 (not found)
cache.get(3)       // returns 3
cache.get(4)       // returns 4

Constraints: 1 <= capacity <= 3000. Up to 200,000 total calls to get and put, so both must be genuinely O(1) — not just "small enough in practice."

——————————————————————————————
WHY INTERVIEWERS ASK THIS (real-world context)
——————————————————————————————
This is one of the most frequently asked Hard questions across Apple, Google, Meta, Amazon, Uber, and Bloomberg for senior iOS/macOS roles, because it mirrors real production work: image/thumbnail caches, URLCache-style response caches, and NSCache-adjacent in-memory stores all rely on exactly this eviction strategy. It tests whether you can combine two data structures — a hash table and a doubly linked list — to hit a hard O(1) requirement that neither one achieves alone.

——————————————————————————————
COMMON MISTAKES CANDIDATES MAKE
——————————————————————————————
- Using only a Dictionary and tracking recency with an Array — array removal/reordering is O(n), which fails the O(1) bar under scrutiny.
- Forgetting that get() must also refresh recency (many candidates only update order on put()).
- Forgetting that put() on an EXISTING key must refresh recency too, not just the insert-new-key eviction path.
- Evicting before checking whether the key already exists (an update never needs an eviction).
- Reaching for Dictionary insertion order or NSOrderedSet as a substitute for a real doubly linked list — neither gives true O(1) "move to front."
- Not handling get() on an empty/missing key cleanly (returning something other than -1, or force-unwrapping into a crash).

——————————————————————————————
HINTS (if stuck)
——————————————————————————————
1. What single data structure gives O(1) lookup? What separate structure gives O(1) "move to front" and O(1) removal from an arbitrary position?
2. A doubly linked list lets you unlink and relink a node in O(1) if you already hold a reference to it — so what should the Dictionary's values actually be?
3. Use two dummy sentinel nodes (head/tail) so you never have to special-case insertion or removal at the boundaries.

——————————————————————————————
FOLLOW-UP QUESTIONS AN INTERVIEWER MAY ASK
——————————————————————————————
- How would you make this thread-safe if get/put could be called from multiple threads concurrently (e.g. background image loads plus main-thread cache reads)?
- How would you turn this into an LFU (Least Frequently Used) cache instead — what actually changes?
- How would you add a per-entry TTL so items expire even if capacity is never reached?
- How would you persist this cache to disk so it survives an app relaunch, without blocking the calling thread?
- What Apple framework already gives you a similar (but not identical) eviction cache, and how does it differ from what you just built? (NSCache — it is not strictly LRU, does not guarantee a specific eviction order, and auto-purges under memory pressure.)

——————————————————————————————
REAL-WORLD SCENARIO
——————————————————————————————
Your app has an image gallery that downloads and caches full-resolution photos in memory for smooth scrolling. Users report that scrolling a very long gallery eventually triggers a memory warning and visible image flicker, because an ad-hoc "clear the cache at 100 items" heuristic evicts unpredictably. The fix in production is exactly the class you're building here: a genuine bounded LRU so the most recently viewed photos always stay resident and older ones are evicted deterministically.

——————————————————————————————
EVALUATION RUBRIC (what a strong answer demonstrates)
——————————————————————————————
- Correctly identifies hash table + doubly linked list as the required combination — and actually implements it, not just names it.
- Both get() and put() correctly refresh recency.
- Eviction only happens when inserting a genuinely new key while already at capacity.
- Uses sentinel head/tail nodes (or otherwise cleanly handles boundary conditions) instead of scattering nil-checks everywhere.
- Can state the O(1) time complexity claim precisely, per operation.
- Engages with the follow-up questions above using real tradeoffs, not buzzwords.

——————————————————————————————
INTERVIEW METADATA
——————————————————————————————
Recommended duration: 20–30 minutes for a first working version in a live-coding round, plus 5–10 minutes of follow-up discussion on thread-safety and NSCache differences.
Asked at: Apple, Google, Meta, Amazon, Uber, Bloomberg, Microsoft, and effectively every FAANG-adjacent mobile team.
""",
                templateCode: """
class LRUCache {
    init(_ capacity: Int) {
        // TODO: Store capacity and set up your data structures
    }

    func get(_ key: Int) -> Int {
        // TODO: Return the value for key if present (and mark it as recently used), otherwise -1
        return -1
    }

    func put(_ key: Int, _ value: Int) {
        // TODO: Insert or update the value for key (marking it as recently used).
        // If the cache is at capacity, evict the least recently used entry first.
    }
}
""",
                solutionCode: """
class LRUCache {
    private class Node {
        let key: Int
        var value: Int
        var prev: Node?
        var next: Node?
        init(key: Int, value: Int) {
            self.key = key
            self.value = value
        }
    }

    private let capacity: Int
    private var nodes: [Int: Node] = [:]
    private let head = Node(key: -1, value: -1)
    private let tail = Node(key: -1, value: -1)

    init(_ capacity: Int) {
        self.capacity = capacity
        head.next = tail
        tail.prev = head
    }

    func get(_ key: Int) -> Int {
        guard let node = nodes[key] else { return -1 }
        moveToFront(node)
        return node.value
    }

    func put(_ key: Int, _ value: Int) {
        if let node = nodes[key] {
            node.value = value
            moveToFront(node)
            return
        }

        if nodes.count >= capacity, let lru = tail.prev, lru !== head {
            remove(lru)
            nodes.removeValue(forKey: lru.key)
        }

        let node = Node(key: key, value: value)
        nodes[key] = node
        insertAtFront(node)
    }

    private func moveToFront(_ node: Node) {
        remove(node)
        insertAtFront(node)
    }

    private func remove(_ node: Node) {
        if let prev = node.prev {
            prev.next = node.next
        }
        if let next = node.next {
            next.prev = node.prev
        }
    }

    private func insertAtFront(_ node: Node) {
        node.next = head.next
        node.prev = head
        head.next?.prev = node
        head.next = node
    }
}
""",
                testHarness: """
enum Op {
    case get(Int)
    case put(Int, Int)
}
struct TestCase {
    let capacity: Int
    let ops: [Op]
    let expectedGets: [Int]
    let name: String
}
let testCases: [TestCase] = [
    TestCase(capacity: 2, ops: [.put(1,1), .put(2,2), .get(1), .put(3,3), .get(2), .put(4,4), .get(1), .get(3), .get(4)], expectedGets: [1,-1,-1,3,4], name: "Example 1 (Canonical LRU Sequence, capacity 2)"),
    TestCase(capacity: 1, ops: [.put(1,1), .get(1), .put(2,2), .get(1), .get(2)], expectedGets: [1,-1,2], name: "Capacity 1 (Immediate Eviction)"),
    TestCase(capacity: 2, ops: [.put(1,1), .put(2,2), .put(1,10), .get(1), .get(2)], expectedGets: [10,2], name: "Update Existing Key Refreshes Recency"),
    TestCase(capacity: 3, ops: [.put(1,1), .put(2,2), .put(3,3), .get(1), .get(2), .get(3)], expectedGets: [1,2,3], name: "No Eviction Needed (Under Capacity)"),
    TestCase(capacity: 2, ops: [.put(1,1), .put(2,2), .get(1), .get(2), .put(3,3), .get(1), .get(2), .get(3)], expectedGets: [1,2,-1,2,3], name: "Recency Reordering Changes Eviction Victim"),
    TestCase(capacity: 1, ops: [.put(1,1), .put(1,2), .get(1)], expectedGets: [2], name: "Repeated Put On Same Key Updates Value"),
    TestCase(capacity: 2, ops: [.get(5)], expectedGets: [-1], name: "Get On Empty Cache Misses"),
    TestCase(capacity: 2, ops: [.put(1,1), .put(2,2), .put(3,3), .put(4,4), .get(1), .get(2), .get(3), .get(4)], expectedGets: [-1,-1,3,4], name: "Multiple Sequential Evictions")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let cache = LRUCache(tc.capacity)
    var actualGets: [Int] = []
    for op in tc.ops {
        switch op {
        case .get(let key):
            actualGets.append(cache.get(key))
        case .put(let key, let value):
            cache.put(key, value)
        }
    }
    let endTime = DispatchTime.now()
    let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
    let timeInterval = Double(nanoTime) / 1_000_000.0
    if actualGets == tc.expectedGets {
        print("CASE \\(index) | PASS | Name: \\(tc.name) | Output: \\(actualGets) | Expected: \\(tc.expectedGets) | Time: \\(String(format: "%.3f", timeInterval))ms")
        passedCount += 1
    } else {
        print("CASE \\(index) | FAIL | Name: \\(tc.name) | Output: \\(actualGets) | Expected: \\(tc.expectedGets) | Time: \\(String(format: "%.3f", timeInterval))ms")
    }
}
print("SUMMARY | \\(passedCount)/\\(testCases.count) PASSED")
print("---DSA_TEST_RESULTS_END---")
"""
            ),
            Question(
                id: "merge_intervals",
                title: "Merge Intervals",
                category: "dsa",
                difficulty: "Medium",
                topics: ["Array", "Sorting", "Intervals"],
                description: """
Given an array of intervals where intervals[i] = [starti, endi], merge all overlapping intervals and return an array of the non-overlapping intervals that cover all the intervals in the input.

Two intervals [a, b] and [c, d] overlap (and must be merged) if they share at least one point in common — including when one interval's end exactly equals the other's start (e.g. [1,4] and [4,5] merge into [1,5]).

Example:
Input:  intervals = [[1,3],[2,6],[8,10],[15,18]]
Output: [[1,6],[8,10],[15,18]]
Explanation: [1,3] and [2,6] overlap, so they merge into [1,6].

Input:  intervals = [[1,4],[4,5]]
Output: [[1,5]]
Explanation: intervals [1,4] and [4,5] are considered overlapping since they touch at 4.

Constraints: 1 <= intervals.length <= 10^4. intervals[i].length == 2. 0 <= starti <= endi <= 10^5. The input array is not guaranteed to be pre-sorted.

——————————————————————————————
WHY INTERVIEWERS ASK THIS (real-world context)
——————————————————————————————
Merge Intervals is a top-tier "sort first, then sweep" question asked constantly at Apple, Google, Meta, Amazon, and Microsoft because it maps directly onto real calendar/scheduling systems (merging overlapping meeting blocks), resource allocation (combining overlapping reserved time slots), and even UI layout algorithms (collapsing overlapping highlighted text ranges). It tests whether a candidate reaches for sorting as a simplification tool before reaching for a more complex data structure, and whether they handle the boundary/touching-interval edge case correctly.

——————————————————————————————
COMMON MISTAKES CANDIDATES MAKE
——————————————————————————————
- Forgetting to sort the intervals first — without sorting, a correct single-pass merge is not possible at all.
- Using strict less-than (<) instead of <=/>= when comparing the current interval's start to the previous merged interval's end, which silently fails on touching intervals like [1,4] and [4,5].
- Mutating the input array's inner arrays in place in a way that corrupts the "previous merged interval" reference used on the next iteration.
- Comparing only against the immediately previous ORIGINAL interval instead of the previous MERGED interval — a merged interval's end can extend further than any single original interval's end, and subsequent intervals must be compared against that extended value.
- Off-by-one or empty-array crashes: not guarding against an empty input, or force-unwrapping the first sorted interval unsafely.

——————————————————————————————
HINTS (if stuck)
——————————————————————————————
1. If the intervals were already sorted by start time, could you solve this in one linear pass? What does that suggest as a required first step?
2. Keep a running "current merged interval" — for each next interval, either extend the current one's end, or close it out and start a new one.
3. Be careful about which end value you take the max of — a later interval can be fully contained within an earlier, wider merged interval.

——————————————————————————————
FOLLOW-UP QUESTIONS AN INTERVIEWER MAY ASK
——————————————————————————————
- How would you solve this if the intervals arrived as a continuous stream (an "Insert Interval" variant) rather than all at once?
- What's the time complexity, and is the O(n log n) sort unavoidable, or could you do better if the inputs were already known to be sorted?
- How would you also return, for each merged interval, which original input intervals contributed to it?
- How would this change if intervals could have open vs. closed boundaries (i.e. [1,4) not overlapping [4,5))?

——————————————————————————————
REAL-WORLD SCENARIO
——————————————————————————————
Your calendar app lets a user create multiple overlapping "busy" blocks throughout the day (an all-day meeting, a few one-off calls, a recurring standup). Before rendering the day view, you need to collapse these into the minimal set of non-overlapping busy ranges so the UI can draw clean, non-overlapping colored bars instead of stacking dozens of overlapping rectangles. This function is exactly that collapsing step.

——————————————————————————————
EVALUATION RUBRIC (what a strong answer demonstrates)
——————————————————————————————
- Sorts by interval start before attempting any merge logic.
- Correctly treats touching intervals (end == next start) as overlapping.
- Compares against the running merged interval's end, not the original previous interval's end.
- Produces the correct output on unsorted input, single-interval input, and fully-nested input.
- Can state and justify the O(n log n) time complexity (dominated by the sort).

——————————————————————————————
INTERVIEW METADATA
——————————————————————————————
Recommended duration: 15–20 minutes for a working solution, plus a few minutes discussing the streaming/Insert Interval follow-up.
Asked at: Apple, Google, Meta, Amazon, Microsoft, LinkedIn, and most mid-to-senior mobile/backend interview loops.
""",
                templateCode: """
class Solution {
    func merge(_ intervals: [[Int]]) -> [[Int]] {
        // TODO: Sort intervals by start, then sweep through merging overlapping/touching ones
        return []
    }
}
""",
                solutionCode: """
class Solution {
    func merge(_ intervals: [[Int]]) -> [[Int]] {
        guard !intervals.isEmpty else { return [] }
        let sorted = intervals.sorted { $0[0] < $1[0] }
        var result: [[Int]] = [sorted[0]]
        for interval in sorted.dropFirst() {
            if interval[0] <= result[result.count - 1][1] {
                result[result.count - 1][1] = max(result[result.count - 1][1], interval[1])
            } else {
                result.append(interval)
            }
        }
        return result
    }
}
""",
                testHarness: """
struct TestCase {
    let intervals: [[Int]]
    let expected: [[Int]]
    let name: String
}
let testCases: [TestCase] = [
    TestCase(intervals: [[1,3],[2,6],[8,10],[15,18]], expected: [[1,6],[8,10],[15,18]], name: "Example 1 (Classic Overlap Chain)"),
    TestCase(intervals: [[1,4],[4,5]], expected: [[1,5]], name: "Touching Intervals Merge"),
    TestCase(intervals: [], expected: [], name: "Empty Input"),
    TestCase(intervals: [[1,4]], expected: [[1,4]], name: "Single Interval"),
    TestCase(intervals: [[1,4],[2,3]], expected: [[1,4]], name: "Fully Contained Interval"),
    TestCase(intervals: [[1,10],[2,3],[4,5],[6,7]], expected: [[1,10]], name: "All Contained In First"),
    TestCase(intervals: [[1,2],[3,4],[5,6]], expected: [[1,2],[3,4],[5,6]], name: "No Overlaps"),
    TestCase(intervals: [[2,3],[1,2]], expected: [[1,3]], name: "Unsorted Input, Touching")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = Solution().merge(tc.intervals)
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
                id: "word_break",
                title: "Word Break",
                category: "dsa",
                difficulty: "Medium",
                topics: ["DP", "String", "Hash Table"],
                description: """
Given a string s and a dictionary of strings wordDict, return true if s can be segmented into a space-separated sequence of one or more dictionary words.

Note: the same word in wordDict may be reused any number of times in the segmentation.

Example:
Input:  s = "leetcode", wordDict = ["leet", "code"]
Output: true
Explanation: "leetcode" segments as "leet code".

Input:  s = "catsandog", wordDict = ["cats", "dog", "sand", "and", "cat"]
Output: false
Explanation: Every prefix-based greedy split ("cats" + "and" + "og", or "cat" + "sand" + "og") leaves a leftover chunk ("og") that isn't in the dictionary — there is no valid full segmentation.

Constraints: 1 <= s.length <= 300. 1 <= wordDict.length <= 1000. 1 <= wordDict[i].length <= 20. s and wordDict[i] consist of lowercase English letters only. All strings in wordDict are unique.

——————————————————————————————
WHY INTERVIEWERS ASK THIS (real-world context)
——————————————————————————————
Word Break is a canonical "1D DP over string prefixes" problem asked at Apple, Google, Meta, and Amazon because it separates candidates who reach for a real dynamic-programming state (dp[i] = "can the prefix ending at i be fully segmented?") from those who try brute-force recursive backtracking and get an exponential blowup on longer inputs. It also tests whether a candidate falls into the classic greedy trap the "catsandog" example is specifically designed to expose.

——————————————————————————————
COMMON MISTAKES CANDIDATES MAKE
——————————————————————————————
- Greedily taking the first/longest dictionary word that matches at each position instead of trying all valid split points — this fails on inputs like "catsandog" where a locally-good split (e.g. "cats") makes the rest of the string unsegmentable.
- Writing plain recursive backtracking with no memoization, which is exponential (roughly 2^n) and times out on longer strings — the "aaaa...aaab" style test case exists specifically to catch this.
- Off-by-one errors in the dp array indexing — dp typically needs length n+1 (one extra slot for the empty prefix, dp[0] = true), and it's easy to misalign substring bounds against it.
- Not restricting the inner loop's candidate word length to the dictionary's actual word lengths, causing needless O(n^3) substring-hashing work on long strings when it isn't necessary (a valid follow-up optimization, not required for correctness).
- Using a Dictionary/Array wordDict lookup (O(n) per check) instead of a Set, silently making the whole algorithm much slower.

——————————————————————————————
HINTS (if stuck)
——————————————————————————————
1. Define dp[i] = true if the prefix s[0..<i] can be fully segmented using words from the dictionary. What's the base case, and what's the final answer in terms of dp?
2. To compute dp[end], check every start < end where dp[start] is already true — is the substring s[start..<end] in the dictionary?
3. Converting wordDict to a Set up front turns each substring membership check into O(1) average instead of O(n).

——————————————————————————————
FOLLOW-UP QUESTIONS AN INTERVIEWER MAY ASK
——————————————————————————————
- How would you modify this to return one actual valid segmentation (not just true/false)? What about ALL valid segmentations (Word Break II)?
- What is the time and space complexity of your DP solution, and how does the dictionary's word-length distribution affect it in practice?
- How would you use a Trie of the dictionary words to prune the inner loop instead of hashing every candidate substring?
- How would memoized recursion compare to the bottom-up DP table here — any meaningful difference in this case?

——————————————————————————————
REAL-WORLD SCENARIO
——————————————————————————————
An autocomplete/spell-correction feature needs to check whether a run-together string of characters (e.g. text pasted without spaces, or a hashtag like "#icanhazcheeseburger") can plausibly be split into real dictionary words, so it can suggest re-inserting spaces. The core feasibility check — "can this string be fully covered by dictionary words end-to-end?" — is exactly this problem.

——————————————————————————————
EVALUATION RUBRIC (what a strong answer demonstrates)
——————————————————————————————
- Identifies this as a DP-over-prefixes problem rather than reaching for unmemoized recursion or a greedy split.
- Correctly defines and initializes the dp array, including the dp[0] = true base case.
- Handles the "catsandog"-style trap correctly (recognizes it must return false).
- Uses a Set for O(1) dictionary lookups.
- Can state the O(n^2) (or better, with length pruning) time complexity and justify it.

——————————————————————————————
INTERVIEW METADATA
——————————————————————————————
Recommended duration: 20–25 minutes for a working DP solution, plus discussion of the Word Break II / actual-segmentation follow-up if time allows.
Asked at: Apple, Google, Meta, Amazon, Bloomberg, and frequently paired with Word Break II in longer onsite loops.
""",
                templateCode: """
class Solution {
    func wordBreak(_ s: String, _ wordDict: [String]) -> Bool {
        // TODO: dp[i] = can prefix of length i be segmented using words from wordDict?
        return false
    }
}
""",
                solutionCode: """
class Solution {
    func wordBreak(_ s: String, _ wordDict: [String]) -> Bool {
        guard !s.isEmpty else { return true }
        let wordSet = Set(wordDict)
        let chars = Array(s)
        var dp = [Bool](repeating: false, count: chars.count + 1)
        dp[0] = true
        for end in 1...chars.count {
            for start in 0..<end {
                if dp[start] {
                    let sub = String(chars[start..<end])
                    if wordSet.contains(sub) {
                        dp[end] = true
                        break
                    }
                }
            }
        }
        return dp[chars.count]
    }
}
""",
                testHarness: """
struct TestCase {
    let s: String
    let wordDict: [String]
    let expected: Bool
    let name: String
}
let testCases: [TestCase] = [
    TestCase(s: "leetcode", wordDict: ["leet", "code"], expected: true, name: "Classic Two-Word Split"),
    TestCase(s: "applepenapple", wordDict: ["apple", "pen"], expected: true, name: "Reused Dictionary Words"),
    TestCase(s: "catsandog", wordDict: ["cats", "dog", "sand", "and", "cat"], expected: false, name: "Classic Trap: Greedy Fails"),
    TestCase(s: "", wordDict: ["a"], expected: true, name: "Empty String"),
    TestCase(s: "a", wordDict: ["a"], expected: true, name: "Single Char Match"),
    TestCase(s: "aaaaaaa", wordDict: ["aaaa", "aaa"], expected: true, name: "Overlapping Ambiguous Segments"),
    TestCase(s: "abcd", wordDict: ["a", "abc", "b", "cd"], expected: true, name: "Multiple Valid Paths"),
    TestCase(s: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab", wordDict: ["a","aa","aaa","aaaa","aaaaa","aaaaaa","aaaaaaa","aaaaaaaa","aaaaaaaaa","aaaaaaaaaa"], expected: false, name: "Exponential Blowup Guard (No Memo Would TLE)")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = Solution().wordBreak(tc.s, tc.wordDict)
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
                id: "number_of_islands",
                title: "Number of Islands",
                category: "dsa",
                difficulty: "Medium",
                topics: ["Graph", "DFS", "BFS", "Matrix"],
                description: """
Given an m x n 2D binary grid which represents a map of '1's (land) and '0's (water), return the number of islands.

An island is surrounded by water and is formed by connecting adjacent lands horizontally or vertically (NOT diagonally). You may assume all four edges of the grid are surrounded by water.

Example:
Input:
grid = [
  ["1","1","1","1","0"],
  ["1","1","0","1","0"],
  ["1","1","0","0","0"],
  ["0","0","0","0","0"]
]
Output: 1

Input:
grid = [
  ["1","1","0","0","0"],
  ["1","1","0","0","0"],
  ["0","0","1","0","0"],
  ["0","0","0","1","1"]
]
Output: 3

Constraints: m == grid.length. n == grid[i].length. 1 <= m, n <= 300. grid[i][j] is '0' or '1' (Character, not Int).

——————————————————————————————
WHY INTERVIEWERS ASK THIS (real-world context)
——————————————————————————————
Number of Islands is one of the most commonly asked graph-traversal questions across Apple, Google, Meta, Amazon, and Microsoft because it's the simplest possible test of connected-components thinking on an implicit grid graph: no adjacency list is given, the graph structure (4-directional neighbors) has to be inferred from grid coordinates. It's a gateway to a huge family of similar problems (Max Area of Island, Surrounded Regions, Number of Provinces, Flood Fill) and tests whether a candidate can correctly implement DFS/BFS with proper visited-tracking and boundary checks without an off-by-one crash.

——————————————————————————————
COMMON MISTAKES CANDIDATES MAKE
——————————————————————————————
- Forgetting to mark cells as visited (or sink them in-place), causing infinite recursion or double-counting the same island.
- Checking diagonal neighbors in addition to the four orthogonal ones — diagonally-touching land cells are explicitly NOT the same island per the problem statement.
- Missing or incorrect boundary checks (row/col < 0 or >= grid dimensions) before indexing into the grid, causing an out-of-bounds crash.
- Mutating the original grid parameter directly when the caller still needs it afterward, instead of working on a copy or a separate visited set — a subtle bug that doesn't affect this problem's grading but breaks callers who reuse the grid.
- Using unbounded recursion depth on very large grids (up to 300x300 = 90,000 cells) without considering that a purely recursive DFS could risk a stack overflow in some languages/runtimes — worth mentioning even if Swift's default stack handles this fine at this scale.

——————————————————————————————
HINTS (if stuck)
——————————————————————————————
1. Scan every cell; whenever you find an unvisited '1', that's a brand-new island — increment your counter once, then "flood fill" outward from it to mark every connected land cell as visited so it's never counted again.
2. DFS (recursive or with an explicit stack) and BFS (with a queue) both work equally well here — pick whichever you're more comfortable implementing correctly under pressure.
3. You don't need a separate visited grid if you're allowed to mutate the input: flip visited '1' cells to '0' as you sink them.

——————————————————————————————
FOLLOW-UP QUESTIONS AN INTERVIEWER MAY ASK
——————————————————————————————
- How would you find the size of the LARGEST island instead of just counting how many there are (Max Area of Island)?
- How would you solve this iteratively with an explicit stack/queue instead of recursion, and why might that matter for a 300x300 grid?
- How would this change if islands were also connected diagonally?
- How would you handle this if the grid were streamed in row-by-row and didn't fully fit in memory (Union-Find with row-pair merging)?

——————————————————————————————
REAL-WORLD SCENARIO
——————————————————————————————
A map-rendering feature needs to identify and label each disconnected landmass on a tile-based world map so it can compute per-region statistics (area, centroid, bounding box) and let users tap a landmass to see its name. The core "how many distinct connected regions of land exist in this grid" computation is exactly this algorithm.

——————————————————————————————
EVALUATION RUBRIC (what a strong answer demonstrates)
——————————————————————————————
- Correctly implements a flood-fill (DFS or BFS) with proper 4-directional boundary checks.
- Marks visited cells so each island is counted exactly once.
- Handles an empty grid and a grid with no land cleanly (returns 0).
- Can state the O(rows × cols) time and space complexity.
- Engages meaningfully with at least one follow-up (Max Area of Island or iterative traversal) if asked.

——————————————————————————————
INTERVIEW METADATA
——————————————————————————————
Recommended duration: 15–20 minutes for a working solution; this is usually a warm-up/easy-medium question in a longer loop rather than the main event.
Asked at: Apple, Google, Meta, Amazon, Microsoft, Bloomberg — extremely high frequency across all levels.
""",
                templateCode: """
class Solution {
    func numIslands(_ grid: [[Character]]) -> Int {
        // TODO: Scan the grid; on each unvisited '1', increment count and flood-fill (DFS/BFS) to sink the whole island
        return 0
    }
}
""",
                solutionCode: """
class Solution {
    func numIslands(_ grid: [[Character]]) -> Int {
        guard !grid.isEmpty, !grid[0].isEmpty else { return 0 }
        var visited = grid
        let rows = grid.count
        let cols = grid[0].count
        var count = 0

        func sink(_ r: Int, _ c: Int) {
            if r < 0 || r >= rows || c < 0 || c >= cols { return }
            if visited[r][c] != "1" { return }
            visited[r][c] = "0"
            sink(r + 1, c)
            sink(r - 1, c)
            sink(r, c + 1)
            sink(r, c - 1)
        }

        for r in 0..<rows {
            for c in 0..<cols {
                if visited[r][c] == "1" {
                    count += 1
                    sink(r, c)
                }
            }
        }
        return count
    }
}
""",
                testHarness: """
struct TestCase {
    let grid: [[Character]]
    let expected: Int
    let name: String
}
let testCases: [TestCase] = [
    TestCase(grid: [
        ["1","1","1","1","0"],
        ["1","1","0","1","0"],
        ["1","1","0","0","0"],
        ["0","0","0","0","0"]
    ], expected: 1, name: "One Large Connected Island"),
    TestCase(grid: [
        ["1","1","0","0","0"],
        ["1","1","0","0","0"],
        ["0","0","1","0","0"],
        ["0","0","0","1","1"]
    ], expected: 3, name: "Three Separate Islands"),
    TestCase(grid: [["0"]], expected: 0, name: "Single Water Cell"),
    TestCase(grid: [["1"]], expected: 1, name: "Single Land Cell"),
    TestCase(grid: [], expected: 0, name: "Empty Grid"),
    TestCase(grid: [
        ["1","0","1","0","1"]
    ], expected: 3, name: "Single Row Alternating"),
    TestCase(grid: [
        ["1"],
        ["0"],
        ["1"],
        ["0"],
        ["1"]
    ], expected: 3, name: "Single Column Alternating"),
    TestCase(grid: [
        ["1","1","1"],
        ["1","1","1"],
        ["1","1","1"]
    ], expected: 1, name: "Fully Land Grid")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = Solution().numIslands(tc.grid)
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
                id: "kth_largest_element",
                title: "Kth Largest Element in an Array",
                category: "dsa",
                difficulty: "Medium",
                topics: ["Heap", "Sorting", "Array", "Quickselect"],
                description: """
Given an integer array nums and an integer k, return the kth largest element in the array. Note that it is the kth largest element in sorted order, not the kth distinct element.

Example:
Input:  nums = [3,2,1,5,6,4], k = 2
Output: 5
Explanation: sorted descending is [6,5,4,3,2,1]; the 2nd largest is 5.

Input:  nums = [3,2,3,1,2,4,5,5,6], k = 4
Output: 4
Explanation: sorted descending is [6,5,5,4,3,3,2,2,1]; the 4th largest (counting duplicates) is 4.

Constraints: 1 <= k <= nums.length <= 10^5. -10^4 <= nums[i] <= 10^4.

——————————————————————————————
WHY INTERVIEWERS ASK THIS (real-world context)
——————————————————————————————
This question is a staple at Apple, Google, Meta, and Amazon precisely because the "obvious" solution (sort everything, index in) is only O(n log n) and correct-but-suboptimal — the interesting part of the interview is the follow-up discussion about doing better with a fixed-size min-heap (O(n log k)) or Quickselect (average O(n)). It tests whether a candidate can reason about which approach's complexity actually matters at a given input scale, not just whether they can produce a correct answer.

——————————————————————————————
COMMON MISTAKES CANDIDATES MAKE
——————————————————————————————
- Confusing "kth largest" with "kth distinct largest" — duplicates count individually unless the problem explicitly says otherwise (this one does not).
- Off-by-one indexing after sorting: forgetting that "kth largest" in a descending sort is index (k - 1), or in an ascending sort is index (nums.count - k).
- Implementing a full heap-based solution but pushing ALL n elements onto an unbounded heap instead of maintaining a heap capped at size k — losing the actual efficiency win of the heap approach.
- Attempting Quickselect without properly handling the partition step's pivot selection, leading to O(n^2) worst-case behavior on already-sorted or adversarial inputs without even realizing why.
- Not clarifying with the interviewer whether nums may be mutated in place — some implementations (Quickselect) naturally reorder the input array, which may or may not be acceptable.

——————————————————————————————
HINTS (if stuck)
——————————————————————————————
1. The simplest correct approach: sort descending and index in. What's its time complexity, and when would that not be good enough?
2. Better: maintain a min-heap of size k as you scan nums once — if the heap grows beyond k, pop the minimum. What's left in the heap once you've processed every element?
3. Best average case: Quickselect (partition-based, like a partial QuickSort) finds the kth order statistic in O(n) average time without fully sorting.

——————————————————————————————
FOLLOW-UP QUESTIONS AN INTERVIEWER MAY ASK
——————————————————————————————
- What's the time and space complexity of your approach, and how does it compare to the other two (sort / heap / quickselect)?
- How would this change if the array were a live, continuously-updated stream and you needed to answer "what's the kth largest so far" after every insertion?
- What's the worst-case time complexity of Quickselect, and how would you mitigate it (e.g. random pivot selection, median-of-medians)?
- How would you find the k largest elements (not just the kth one) efficiently?

——————————————————————————————
REAL-WORLD SCENARIO
——————————————————————————————
A leaderboard or analytics feature needs to answer "what score would put a player in exactly kth place" out of potentially hundreds of thousands of scores, computed on demand without maintaining a fully sorted list at all times. Finding the kth order statistic efficiently — without a full sort — is exactly this problem.

——————————————————————————————
EVALUATION RUBRIC (what a strong answer demonstrates)
——————————————————————————————
- Produces a correct answer via at least the straightforward sort-based approach.
- Can articulate the heap-based O(n log k) improvement and why it beats full sorting when k is much smaller than n.
- Can at least describe Quickselect's partition-based approach and its average-case O(n) complexity, even if not implementing it live.
- Correctly handles duplicate values and k == nums.count (the smallest element in the array).
- Reasons clearly about time/space tradeoffs rather than defaulting to "just sort it" without acknowledging the tradeoff.

——————————————————————————————
INTERVIEW METADATA
——————————————————————————————
Recommended duration: 15–20 minutes for the sort-based solution plus discussion; 25–30 minutes if asked to implement Quickselect or a bounded heap live.
Asked at: Apple, Google, Meta, Amazon, Microsoft, and an extremely common "easy-to-state, rich-to-discuss" interview staple.
""",
                templateCode: """
class Solution {
    func findKthLargest(_ nums: [Int], _ k: Int) -> Int {
        // TODO: Return the kth largest element (1-indexed from the largest). Consider sort / heap / quickselect tradeoffs.
        return 0
    }
}
""",
                solutionCode: """
class Solution {
    func findKthLargest(_ nums: [Int], _ k: Int) -> Int {
        let sorted = nums.sorted(by: >)
        return sorted[k - 1]
    }
}
""",
                testHarness: """
struct TestCase {
    let nums: [Int]
    let k: Int
    let expected: Int
    let name: String
}
let testCases: [TestCase] = [
    TestCase(nums: [3,2,1,5,6,4], k: 2, expected: 5, name: "Classic Example"),
    TestCase(nums: [3,2,3,1,2,4,5,5,6], k: 4, expected: 4, name: "With Duplicates"),
    TestCase(nums: [1], k: 1, expected: 1, name: "Single Element"),
    TestCase(nums: [1,2], k: 1, expected: 2, name: "Two Elements, K=1"),
    TestCase(nums: [1,2], k: 2, expected: 1, name: "Two Elements, K=2 (Smallest)"),
    TestCase(nums: [-1,-2,-3,-4], k: 1, expected: -1, name: "All Negative Numbers"),
    TestCase(nums: [7,7,7,7,7], k: 3, expected: 7, name: "All Duplicates"),
    TestCase(nums: [9,3,2,4,8], k: 5, expected: 2, name: "K Equals Array Length (Minimum)")
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = Solution().findKthLargest(tc.nums, tc.k)
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
                id: "rate_limiter_token_bucket",
                title: "Design a Rate Limiter (Token Bucket Algorithm)",
                category: "dsa",
                difficulty: "Hard",
                topics: ["System Design", "Rate Limiting", "Simulation"],
                description: """
Design and implement a rate limiter using the Token Bucket algorithm.

Implement the TokenBucketRateLimiter class:
- init(capacity: Int, refillRatePerSecond: Double) creates a bucket that starts full (capacity tokens) and refills continuously at refillRatePerSecond tokens per second, never exceeding capacity.
- func allowRequest(currentTime: Double, cost: Int = 1) -> Bool is called each time a request arrives at currentTime (seconds, monotonically non-decreasing across calls). It should first refill the bucket based on elapsed time since the last refill, then: if at least cost tokens are available, consume them and return true (allow); otherwise return false (reject) and consume nothing.

Example:
limiter = TokenBucketRateLimiter(capacity: 3, refillRatePerSecond: 1)
limiter.allowRequest(currentTime: 0)   // true  (3 -> 2 tokens)
limiter.allowRequest(currentTime: 0)   // true  (2 -> 1 tokens)
limiter.allowRequest(currentTime: 0)   // true  (1 -> 0 tokens)
limiter.allowRequest(currentTime: 0)   // false (bucket empty, no time has passed to refill)
limiter.allowRequest(currentTime: 1)   // true  (1 second elapsed -> +1 token refilled -> consume it)

Constraints: capacity is a positive integer. refillRatePerSecond is a positive Double (may be fractional, e.g. 0.5 tokens/sec). currentTime values passed to successive calls are non-decreasing (never go backward in time). No external timers, DispatchQueues, or background threads are required — refill is computed lazily from elapsed time at each call, which is the standard production implementation of this pattern.

——————————————————————————————
WHY INTERVIEWERS ASK THIS (real-world context)
——————————————————————————————
Rate limiting is one of the most common "mini system design as a coding problem" questions at Apple, Google, Meta, Amazon, Uber, and Stripe, because virtually every production API gateway, login-attempt guard, and push-notification throttle is built on exactly this token bucket (or the closely related leaky bucket) algorithm. It tests whether a candidate can translate a continuous-time process (tokens accruing gradually) into a correct, side-effect-free, lazily-evaluated calculation — without needing a real background timer thread — which is precisely how this is implemented in real rate limiters (e.g. Stripe's and AWS's public rate limiting behavior).

——————————————————————————————
COMMON MISTAKES CANDIDATES MAKE
——————————————————————————————
- Using a background timer/DispatchQueue to "tick" the bucket every N milliseconds — unnecessary, wasteful, and introduces real concurrency bugs; the standard production trick is lazy refill computed from elapsed wall-clock time at request time, exactly as specified here.
- Letting the bucket overfill past capacity after a long idle period (e.g. no requests for an hour) — refill must always be clamped with min(capacity, tokens + elapsed * rate).
- Refilling AFTER checking/consuming tokens instead of BEFORE — this silently uses stale token counts and rejects requests that should have been allowed once refill is accounted for.
- Not updating lastRefillTime on every call (even rejected ones) — if you only update it on successful requests, elapsed-time math double-counts idle time on the next check.
- Comparing tokens as an Int and losing fractional accumulation entirely when refillRatePerSecond is fractional (e.g. 0.5/sec) — tokens must be tracked as a Double internally even though request cost is typically an integer.
- Forgetting request "cost" can be more than 1 (e.g. a batch operation consuming 5 tokens at once) and hardcoding cost as always 1.

——————————————————————————————
HINTS (if stuck)
——————————————————————————————
1. Store tokens as a Double (not Int) so fractional refill rates accumulate correctly between calls, even if requests only ever consume whole tokens.
2. On every call to allowRequest, first compute elapsed = currentTime - lastRefillTime, add elapsed * refillRatePerSecond tokens (clamped at capacity), and update lastRefillTime — THEN check if enough tokens exist for this request.
3. Think about what happens on the very first call, at time 0, with zero elapsed time — the bucket should already start full at construction, not need a "warm-up" tick.

——————————————————————————————
FOLLOW-UP QUESTIONS AN INTERVIEWER MAY ASK
——————————————————————————————
- How would you extend this to support per-user or per-API-key rate limiting instead of one single global bucket (a Dictionary of buckets, keyed by identifier)?
- How does the Token Bucket algorithm differ from the Leaky Bucket and Sliding Window Log/Counter algorithms, and when would you prefer one over another?
- How would you make this thread-safe for concurrent access from multiple threads/tasks (an actor, or a serial DispatchQueue, or a lock)?
- How would you persist bucket state across app restarts, or share it across multiple server instances (e.g. backed by Redis with an atomic Lua script)?
- What HTTP response and headers would you return to a client whose request is rejected (429 Too Many Requests, Retry-After, X-RateLimit-Remaining)?

——————————————————————————————
REAL-WORLD SCENARIO
——————————————————————————————
Your app's backend exposes a "send verification code" endpoint. Without protection, a malicious or buggy client could hammer it hundreds of times per second, running up SMS costs and enabling SMS-bombing abuse. A per-user token bucket — say, 3 requests immediately allowed, refilling at 1 every 30 seconds — throttles this cleanly: legitimate users retrying once or twice are unaffected, while automated abuse is rejected outright. This exact token bucket implementation is the mechanism behind that protection.

——————————————————————————————
EVALUATION RUBRIC (what a strong answer demonstrates)
——————————————————————————————
- Correctly implements lazy, elapsed-time-based refill with no background timer.
- Refill happens before the allow/reject decision on every call, and lastRefillTime updates on every call (not just successful ones).
- Tokens are never allowed to exceed capacity, and are tracked as a Double to support fractional refill rates.
- Correctly supports a variable per-request cost, not just cost == 1.
- Can articulate the tradeoffs between token bucket, leaky bucket, and sliding window approaches when asked.

——————————————————————————————
INTERVIEW METADATA
——————————————————————————————
Recommended duration: 25–35 minutes — this question rewards a working core implementation first, with most of the remaining time spent on the system-design-style follow-ups (per-user limiting, thread-safety, distributed state).
Asked at: Apple, Google, Meta, Amazon, Uber, Stripe, and any company with a public-facing API — a very common "coding + system design hybrid" interview format.
""",
                templateCode: """
class TokenBucketRateLimiter {
    init(capacity: Int, refillRatePerSecond: Double) {
        // TODO: Start the bucket full; remember capacity and refill rate
    }

    func allowRequest(currentTime: Double, cost: Int = 1) -> Bool {
        // TODO: Refill based on elapsed time since the last call (capped at capacity), then allow/reject based on available tokens
        return false
    }
}
""",
                solutionCode: """
class TokenBucketRateLimiter {
    private let capacity: Double
    private let refillRatePerSecond: Double
    private var tokens: Double
    private var lastRefillTime: Double

    init(capacity: Int, refillRatePerSecond: Double) {
        self.capacity = Double(capacity)
        self.refillRatePerSecond = refillRatePerSecond
        self.tokens = Double(capacity)
        self.lastRefillTime = 0
    }

    func allowRequest(currentTime: Double, cost: Int = 1) -> Bool {
        refill(currentTime: currentTime)
        let costD = Double(cost)
        if tokens >= costD {
            tokens -= costD
            return true
        }
        return false
    }

    private func refill(currentTime: Double) {
        let elapsed = currentTime - lastRefillTime
        if elapsed > 0 {
            tokens = min(capacity, tokens + elapsed * refillRatePerSecond)
            lastRefillTime = currentTime
        }
    }
}
""",
                testHarness: """
struct TestCase {
    let name: String
    let run: () -> Bool
}
let testCases: [TestCase] = [
    TestCase(name: "Allows burst up to capacity") {
        let limiter = TokenBucketRateLimiter(capacity: 3, refillRatePerSecond: 1)
        return limiter.allowRequest(currentTime: 0) &&
               limiter.allowRequest(currentTime: 0) &&
               limiter.allowRequest(currentTime: 0) &&
               !limiter.allowRequest(currentTime: 0)
    },
    TestCase(name: "Rejects when bucket empty") {
        let limiter = TokenBucketRateLimiter(capacity: 1, refillRatePerSecond: 1)
        let first = limiter.allowRequest(currentTime: 0)
        let second = limiter.allowRequest(currentTime: 0)
        return first && !second
    },
    TestCase(name: "Refills over time allows new request") {
        let limiter = TokenBucketRateLimiter(capacity: 1, refillRatePerSecond: 1)
        let first = limiter.allowRequest(currentTime: 0)
        let blockedImmediately = !limiter.allowRequest(currentTime: 0.1)
        let allowedAfterRefill = limiter.allowRequest(currentTime: 1.0)
        return first && blockedImmediately && allowedAfterRefill
    },
    TestCase(name: "Does not exceed capacity after long idle") {
        let limiter = TokenBucketRateLimiter(capacity: 2, refillRatePerSecond: 5)
        let a = limiter.allowRequest(currentTime: 100)
        let b = limiter.allowRequest(currentTime: 100)
        let c = !limiter.allowRequest(currentTime: 100)
        return a && b && c
    },
    TestCase(name: "Fractional refill rate works correctly") {
        let limiter = TokenBucketRateLimiter(capacity: 5, refillRatePerSecond: 0.5)
        for _ in 0..<5 { _ = limiter.allowRequest(currentTime: 0) }
        let blocked = !limiter.allowRequest(currentTime: 1)
        let allowed = limiter.allowRequest(currentTime: 2)
        return blocked && allowed
    },
    TestCase(name: "Weighted request cost consumes multiple tokens") {
        let limiter = TokenBucketRateLimiter(capacity: 10, refillRatePerSecond: 1)
        let big = limiter.allowRequest(currentTime: 0, cost: 7)
        let tooBig = !limiter.allowRequest(currentTime: 0, cost: 5)
        let smallOk = limiter.allowRequest(currentTime: 0, cost: 3)
        return big && tooBig && smallOk
    },
    TestCase(name: "Sustained rate at exactly refill rate stays allowed") {
        let limiter = TokenBucketRateLimiter(capacity: 1, refillRatePerSecond: 2)
        var allAllowed = true
        var t = 0.0
        for _ in 0..<5 {
            if !limiter.allowRequest(currentTime: t) { allAllowed = false }
            t += 0.5
        }
        return allAllowed
    },
    TestCase(name: "Zero elapsed time between calls does not double count") {
        let limiter = TokenBucketRateLimiter(capacity: 2, refillRatePerSecond: 1)
        let a = limiter.allowRequest(currentTime: 5)
        let b = limiter.allowRequest(currentTime: 5)
        let c = !limiter.allowRequest(currentTime: 5)
        return a && b && c
    }
]
var passedCount = 0
print("---DSA_TEST_RESULTS_START---")
for (index, tc) in testCases.enumerated() {
    let startTime = DispatchTime.now()
    let result = tc.run()
    let endTime = DispatchTime.now()
    let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
    let timeInterval = Double(nanoTime) / 1_000_000.0
    if result == true {
        print("CASE \\(index) | PASS | Name: \\(tc.name) | Output: \\(result) | Expected: true | Time: \\(String(format: "%.3f", timeInterval))ms")
        passedCount += 1
    } else {
        print("CASE \\(index) | FAIL | Name: \\(tc.name) | Output: \\(result) | Expected: true | Time: \\(String(format: "%.3f", timeInterval))ms")
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
            ),
            Question(
                id: "snake_case_converter",
                title: "Snake Case Converter",
                category: "swiftPractice",
                difficulty: "Easy",
                topics: ["String", "Parsing"],
                description: "Write a function that takes a string and returns it in snake_case, where each word is lowercased and separated from adjacent words by a single underscore. The input may contain letters and any combination of delimiter punctuation between words.",
                templateCode: """
import Foundation

func toSnakeCase(_ str: String) -> String {
    // TODO: Write your solution here
    return str
}

print(toSnakeCase("cats AND*Dogs-are Awesome"))
print(toSnakeCase("a b c d-e-f%g"))
""",
                solutionCode: """
import Foundation

func toSnakeCase(_ str: String) -> String {
    var words: [String] = []
    var current = ""
    for char in str {
        if char.isLetter {
            current.append(char)
        } else if !current.isEmpty {
            words.append(current.lowercased())
            current = ""
        }
    }
    if !current.isEmpty {
        words.append(current.lowercased())
    }
    return words.joined(separator: "_")
}

print(toSnakeCase("cats AND*Dogs-are Awesome"))
print(toSnakeCase("a b c d-e-f%g"))
print(toSnakeCase("BOB loves-coding"))
""",
                testHarness: ""
            ),
            Question(
                id: "ios_local_cache",
                title: "iOS Local Cache",
                category: "swiftPractice",
                difficulty: "Medium",
                topics: ["Data Structures", "Dictionary"],
                description: "Implement a simple key-value cache class with add, get, and size functions. add(key, value) returns \"added\" for a new key or \"overwritten\" if the key already existed. get(key) returns the stored value or \"miss\" if absent. size() returns the number of stored items.",
                templateCode: """
import Foundation

class Cache {
    // TODO: implement add, get, and size

    func add(_ key: String, _ value: String) -> String {
        return ""
    }

    func get(_ key: String) -> String {
        return ""
    }

    func size() -> Int {
        return 0
    }
}

let cache = Cache()
var results: [String] = []
results.append(cache.add("a", "value1"))
results.append(cache.add("b", "value2"))
results.append(cache.add("b", "value2"))
results.append(cache.add("rrrrr", "nothing"))
results.append(cache.get("hello"))
results.append(cache.get("world"))
results.append(cache.get("b"))
results.append(cache.get("rrrrr"))
results.append("\\(cache.size())")
print(results.joined(separator: " "))
""",
                solutionCode: """
import Foundation

class Cache {
    private var storage: [String: String] = [:]

    func add(_ key: String, _ value: String) -> String {
        let existed = storage[key] != nil
        storage[key] = value
        return existed ? "overwritten" : "added"
    }

    func get(_ key: String) -> String {
        return storage[key] ?? "miss"
    }

    func size() -> Int {
        return storage.count
    }
}

let cache = Cache()
var results: [String] = []
results.append(cache.add("a", "value1"))
results.append(cache.add("b", "value2"))
results.append(cache.add("b", "value2"))
results.append(cache.add("rrrrr", "nothing"))
results.append(cache.get("hello"))
results.append(cache.get("world"))
results.append(cache.get("b"))
results.append(cache.get("rrrrr"))
results.append("\\(cache.size())")
print(results.joined(separator: " "))
""",
                testHarness: ""
            ),
            Question(
                id: "packed_age_counter",
                title: "Count Ages From a Packed Key-Value String",
                category: "swiftPractice",
                difficulty: "Medium",
                topics: ["Codable", "String Parsing"],
                description: "Decode a JSON object with a single \"data\" key whose value is a string containing repeated \"key=STRING, age=INTEGER\" entries. Count how many entries have an age greater than or equal to 50 and print the result.",
                templateCode: """
import Foundation

struct DataObject: Decodable {
    let data: String
}

func countAgesAtLeast50(_ raw: String) -> Int {
    // TODO: Write your solution here
    return 0
}

let json = "{\\"data\\": \\"key=IAfpK, age=58, key=WNVdi, age=64, key=jp9zt, age=47\\"}"
let jsonData = json.data(using: .utf8)!
let dataObject = try! JSONDecoder().decode(DataObject.self, from: jsonData)
print(countAgesAtLeast50(dataObject.data))
""",
                solutionCode: """
import Foundation

struct DataObject: Decodable {
    let data: String
}

func countAgesAtLeast50(_ raw: String) -> Int {
    let tokens = raw.components(separatedBy: ", ")
    var count = 0
    for token in tokens {
        if token.hasPrefix("age=") {
            let numberPart = token.replacingOccurrences(of: "age=", with: "")
            if let age = Int(numberPart), age >= 50 {
                count += 1
            }
        }
    }
    return count
}

let json = "{\\"data\\": \\"key=IAfpK, age=58, key=WNVdi, age=64, key=jp9zt, age=47\\"}"
let jsonData = json.data(using: .utf8)!
let dataObject = try! JSONDecoder().decode(DataObject.self, from: jsonData)
print(countAgesAtLeast50(dataObject.data))
""",
                testHarness: ""
            ),
            Question(
                id: "github_repository_model",
                title: "GitHub Repository Model (Codable + Identifiable)",
                category: "swiftPractice",
                difficulty: "Easy",
                topics: ["Codable", "Identifiable", "JSON"],
                description: "Create a Repository struct conforming to Codable and Identifiable with id, name, optional language, optional description, and stargazersCount (decoded from the JSON key \"stargazers_count\"). Decode the sample JSON array below and print each repository's details.",
                templateCode: """
import Foundation

struct Repository: Codable, Identifiable {
    // TODO: add id, name, language (optional), description (optional), stargazersCount
    // Note: the JSON key for stargazersCount is "stargazers_count"
}

let json = "[{\\"id\\": 1, \\"name\\": \\"AwesomeProject\\", \\"language\\": \\"Swift\\", \\"description\\": \\"An awesome Swift project.\\", \\"stargazers_count\\": 42}, {\\"id\\": 2, \\"name\\": \\"MissingLanguage\\", \\"description\\": \\"No language provided.\\", \\"stargazers_count\\": 10}, {\\"id\\": 3, \\"name\\": \\"NoDescription\\", \\"language\\": \\"Objective-C\\", \\"stargazers_count\\": 15}]"

let data = json.data(using: .utf8)!
// TODO: decode into [Repository] and print each repository's name, description, language, and star count
""",
                solutionCode: """
import Foundation

struct Repository: Codable, Identifiable {
    let id: Int
    let name: String
    let language: String?
    let description: String?
    let stargazersCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, language, description
        case stargazersCount = "stargazers_count"
    }
}

let json = "[{\\"id\\": 1, \\"name\\": \\"AwesomeProject\\", \\"language\\": \\"Swift\\", \\"description\\": \\"An awesome Swift project.\\", \\"stargazers_count\\": 42}, {\\"id\\": 2, \\"name\\": \\"MissingLanguage\\", \\"description\\": \\"No language provided.\\", \\"stargazers_count\\": 10}, {\\"id\\": 3, \\"name\\": \\"NoDescription\\", \\"language\\": \\"Objective-C\\", \\"stargazers_count\\": 15}]"

let data = json.data(using: .utf8)!
let repositories = try! JSONDecoder().decode([Repository].self, from: data)
for repo in repositories {
    let lang = repo.language ?? "N/A"
    let desc = repo.description ?? "No description."
    print("\\(repo.name) | \\(desc) | Language: \\(lang) | ★\\(repo.stargazersCount)")
}
""",
                testHarness: ""
            ),
            Question(
                id: "actor_reentrancy_bug_fix",
                title: "8. Fix the Actor Reentrancy Bug (Bank Account Race Condition)",
                category: "swiftPractice",
                difficulty: "Hard",
                topics: ["Actors", "Concurrency", "Data Race Safety"],
                description: """
You are given a BankAccount actor with a bug: under concurrent access, it allows a double-withdrawal that overdraws the account below zero — even though actors are supposed to eliminate data races.

The BUGGY version looks like this:

    actor BankAccount {
        private var balance: Int
        init(balance: Int) { self.balance = balance }

        func withdraw(_ amount: Int) async -> Bool {
            guard balance >= amount else { return false }
            await recordAudit("withdraw \\(amount)")   // <-- suspension point BEFORE the mutation
            balance -= amount
            return true
        }

        private func recordAudit(_ entry: String) async {
            await Task.yield()   // simulates writing to disk/network
            // ... append to a log
        }
    }

This compiles cleanly and passes a single-threaded test. But if two withdraw(80) calls race against an account with balance = 100, BOTH can read balance >= 80 as true BEFORE either one's await recordAudit(...) suspends and lets the other proceed — because an actor only guarantees ONE task's code runs at a time BETWEEN suspension points, not across them. The result: both withdrawals succeed, and the final balance can go negative (or at minimum, more money leaves the account than it ever had).

Your task: fix BankAccount so that concurrent withdraw() calls are safe — for any number of simultaneous calls, the actor must never let total withdrawals exceed the balance available at the time withdrawals started being processed, and the account balance must never go negative.

Constraints: You must keep withdraw as an async function (callers await it) and you must keep some form of an awaited call happening as part of a withdrawal's audit trail — you cannot simply delete all concurrency from the type. The fix is about WHERE the suspension point is relative to the balance check-and-mutate, not about removing suspension entirely.

——————————————————————————————
WHY INTERVIEWERS ASK THIS (real-world context)
——————————————————————————————
This is a "trick question" / live-debugging scenario increasingly common in senior Apple/iOS interviews as Swift Concurrency (actors, async/await) has become the default. It directly tests a widely-held misconception: many engineers assume "it's an actor, so it's automatically safe from races" — but actor isolation only guarantees mutual exclusion BETWEEN suspension points (await calls), not across an entire method body that awaits partway through. This is called actor reentrancy, and it's one of the most subtle, real, production-breaking bugs in modern Swift codebases — Apple's own Concurrency documentation and WWDC sessions specifically call it out as a top gotcha.

——————————————————————————————
COMMON MISTAKES CANDIDATES MAKE
——————————————————————————————
- Assuming the actor keyword alone guarantees the whole withdraw() method executes atomically from start to finish — it does not, once an await appears anywhere inside it.
- "Fixing" this by removing the await entirely (e.g. deleting the audit log call) rather than understanding WHY reordering it fixes the actual race — a real interview follow-up will ask you to keep some genuine async work in the method.
- Moving the await to the very end but still performing it BEFORE the return value is honestly synchronized with the balance mutation — subtle reorderings can reintroduce the same bug if the check-mutate pair still straddles a suspension point.
- Believing @MainActor or DispatchQueue.sync could "help" here — this is a different actor's isolation domain issue, not a main-thread-vs-background-thread issue; those tools don't address actor reentrancy at all.
- Not testing with genuinely concurrent async let / Task {} calls — a bug like this can look completely fine in a naive sequential test and only reproduces under real interleaving.

——————————————————————————————
HINTS (if stuck)
——————————————————————————————
1. Within an actor, code runs without interruption ONLY between two consecutive suspension points (await calls) in the SAME task. If task A awaits in the middle of withdraw(), task B's withdraw() call can run its own guard/balance check before task A resumes.
2. The fix: perform the ENTIRE "check balance, then mutate balance" sequence with no await in between — do all side-effecting async work (like the audit log) strictly AFTER the balance has already been safely decremented.
3. Ask yourself: at the exact moment two tasks' guard balance >= amount checks could both evaluate against the same stale balance value, is there an await between the check and the write? If yes, that's the bug.

——————————————————————————————
FOLLOW-UP QUESTIONS AN INTERVIEWER MAY ASK
——————————————————————————————
- What exactly does "actor reentrancy" mean, in your own words, and why doesn't the actor keyword alone prevent it?
- Can you construct another example (outside banking) where actor reentrancy causes a real bug — e.g. a cache that's checked-then-populated across an await?
- How would Swift's (still-evolving) strict concurrency checking / Sendable requirements help catch or fail to catch this kind of bug at compile time?
- If the audit log itself needed to observe the CORRECT pre-transaction balance (not the post-transaction one), how would you restructure this to keep both correctness guarantees?
- How is this different from a classic mutex/lock-based data race in non-actor code — what does the actor model give you "for free," and what does it not?

——————————————————————————————
REAL-WORLD SCENARIO
——————————————————————————————
A payments team ships an actor-isolated WalletService believing "it's an actor, so concurrent transfers are safe." A rushed feature adds an `await` call inside the transfer method to log the transaction to an analytics endpoint before finalizing the balance change — a seemingly harmless addition. Weeks later, a support ticket reports users occasionally seeing negative balances after rapid double-taps on a "Send Money" button (two near-simultaneous transfer requests). This is exactly that bug, reduced to its essential shape.

——————————————————————————————
EVALUATION RUBRIC (what a strong answer demonstrates)
——————————————————————————————
- Correctly diagnoses the root cause as actor reentrancy (a suspension point sitting between the balance check and the balance mutation), not a generic "threading issue."
- Fixes it by moving all await-ing side effects to occur strictly after the balance has been atomically checked-and-mutated with no suspension in between.
- Keeps withdraw as a genuinely async function with real awaited work still present, per the constraints.
- Can verify the fix by reasoning about (or writing) a concurrent test with multiple simultaneous withdrawals that would have failed under the buggy version.
- Articulates the general principle clearly: within an actor, only the code between suspension points is guaranteed uninterrupted — not the whole method.

——————————————————————————————
INTERVIEW METADATA
——————————————————————————————
Recommended duration: 20–30 minutes — this is intentionally a debugging/reasoning question rather than a from-scratch build, so time is split between spotting the bug, explaining the mechanism, and implementing + verifying the fix.
Asked at: Apple (heavily, given Swift Concurrency ownership), and increasingly at any team with a mature Swift Concurrency codebase (Meta's Swift-based tooling, fintech/payments-adjacent iOS teams). Explicitly the kind of "trick question" senior candidates are expected to have encountered.
""",
                templateCode: """
actor BankAccount {
    private var balance: Int
    private(set) var auditLog: [String] = []

    init(balance: Int) {
        self.balance = balance
    }

    func currentBalance() -> Int { balance }

    // TODO: This has an actor-reentrancy bug — under concurrent calls, two withdrawals
    // can both pass the guard check before either one's `await` resumes, allowing an
    // overdraw. Fix it so the balance check-and-mutate happens with no suspension in between,
    // while still keeping a genuinely awaited audit-log call as part of the method.
    func withdraw(_ amount: Int) async -> Bool {
        guard balance >= amount else { return false }
        await recordAudit("withdraw \\(amount)")
        balance -= amount
        return true
    }

    private func recordAudit(_ entry: String) async {
        await Task.yield()
        auditLog.append(entry)
    }
}
""",
                solutionCode: """
actor BankAccount {
    private var balance: Int
    private(set) var auditLog: [String] = []

    init(balance: Int) {
        self.balance = balance
    }

    func currentBalance() -> Int { balance }

    func withdraw(_ amount: Int) async -> Bool {
        guard balance >= amount else { return false }
        balance -= amount
        await recordAudit("withdraw \\(amount)")
        return true
    }

    private func recordAudit(_ entry: String) async {
        await Task.yield()
        auditLog.append(entry)
    }
}
""",
                testHarness: """
func runTwoConcurrentWithdrawals() async -> Bool {
    let account = BankAccount(balance: 100)
    async let r1 = account.withdraw(80)
    async let r2 = account.withdraw(80)
    let (result1, result2) = await (r1, r2)
    let finalBalance = await account.currentBalance()
    let exactlyOneSucceeded = (result1 && !result2) || (!result1 && result2)
    let balanceNeverNegative = finalBalance >= 0
    let balanceConsistent = finalBalance == (exactlyOneSucceeded ? 20 : 100)
    return exactlyOneSucceeded && balanceNeverNegative && balanceConsistent
}

func runManyConcurrentWithdrawals() async -> Bool {
    let account = BankAccount(balance: 100)
    var tasks: [Task<Bool, Never>] = []
    for _ in 0..<10 {
        tasks.append(Task { await account.withdraw(30) })
    }
    var successCount = 0
    for t in tasks {
        if await t.value { successCount += 1 }
    }
    let finalBalance = await account.currentBalance()
    return successCount == 3 && finalBalance == 10
}

struct TestCase {
    let name: String
    let run: () async -> Bool
}
let testCases: [TestCase] = [
    TestCase(name: "Two concurrent withdrawals: exactly one succeeds, no over-withdraw") { await runTwoConcurrentWithdrawals() },
    TestCase(name: "Ten concurrent withdrawals: exactly enough succeed, balance never negative") { await runManyConcurrentWithdrawals() }
]

let semaphore = DispatchSemaphore(value: 0)
Task {
    var passedCount = 0
    print("---DSA_TEST_RESULTS_START---")
    for (index, tc) in testCases.enumerated() {
        let startTime = DispatchTime.now()
        let result = await tc.run()
        let endTime = DispatchTime.now()
        let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000.0
        if result == true {
            print("CASE \\(index) | PASS | Name: \\(tc.name) | Output: \\(result) | Expected: true | Time: \\(String(format: "%.3f", timeInterval))ms")
            passedCount += 1
        } else {
            print("CASE \\(index) | FAIL | Name: \\(tc.name) | Output: \\(result) | Expected: true | Time: \\(String(format: "%.3f", timeInterval))ms")
        }
    }
    print("SUMMARY | \\(passedCount)/\\(testCases.count) PASSED")
    print("---DSA_TEST_RESULTS_END---")
    semaphore.signal()
}
semaphore.wait()
"""
            )
        ]
    }
}
