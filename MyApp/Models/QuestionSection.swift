import Foundation

public struct QuestionSection {
    public let name: String
    public let questions: [Question]
}

/// Groups questions into curated topic sections for sidebar browsing.
///
/// Sections are derived from each `Question.topics` array — the same data
/// already authored per-question — rather than a separate id -> section
/// lookup table. A parallel table would be one more place to update (and
/// forget to update) whenever a question is added, mirroring the exact
/// drift bug already hit once between `dsa_questions.json` and
/// `DatabaseService`'s fallback arrays.
public enum QuestionSectionizer {
    /// Checked top-to-bottom per question; the first entry whose keywords
    /// intersect the question's topics wins. The last entry in each list is
    /// the catch-all bucket (empty keyword set) for anything unmatched.
    private static let dsaOrder: [(section: String, keywords: Set<String>)] = [
        ("Sliding Window", ["Sliding Window"]),
        ("Binary Search", ["Binary Search"]),
        ("Stack", ["Stack", "Monotonic Stack"]),
        ("Graphs & Matrix Traversal", ["Graph", "DFS", "BFS"]),
        ("Dynamic Programming", ["DP", "Unbounded Knapsack"]),
        ("Design & Caching", ["LRU", "Cache Design", "System Design"]),
        ("Linked List", ["Linked List"]),
        ("Simulation & Design", ["Simulation"]),
        ("Arrays & Hashing", [])
    ]

    private static let swiftOrder: [(section: String, keywords: Set<String>)] = [
        ("Networking & APIs", ["URLSession", "Networking", "JSON", "HTTP POST"]),
        ("Concurrency & Memory", ["ARC", "Actors", "Concurrency", "Copy-On-Write", "COW", "Memory Management", "Memory Optimization", "Data Race Safety"]),
        ("Combine & Property Wrappers", ["Combine", "Publishers", "Property Wrappers"]),
        ("Data Structures & Parsing", [])
    ]

    public static func sectionName(for question: Question) -> String {
        let order = question.category == "dsa" ? dsaOrder : swiftOrder
        let topics = Set(question.topics)
        for entry in order where !entry.keywords.isEmpty {
            if !entry.keywords.isDisjoint(with: topics) {
                return entry.section
            }
        }
        return order.last?.section ?? "Other"
    }

    /// Groups `questions` into sections, preserving the curated order above
    /// and dropping any section with no matching questions.
    public static func grouped(_ questions: [Question], category: String) -> [QuestionSection] {
        let order = (category == "dsa" ? dsaOrder : swiftOrder).map { $0.section }
        var buckets: [String: [Question]] = [:]
        for q in questions {
            buckets[sectionName(for: q), default: []].append(q)
        }
        return order.compactMap { name in
            guard let qs = buckets[name], !qs.isEmpty else { return nil }
            return QuestionSection(name: name, questions: qs)
        }
    }
}
