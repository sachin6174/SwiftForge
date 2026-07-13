import Foundation

/// A single interview Q&A entry: a question paired with a deeply-explained
/// answer — prose explanation, a runnable Swift example illustrating it, and
/// bullet-point takeaways — rather than the single-line answer an MCQ has.
/// Deliberately a separate model from `MCQQuestion` (no options/correct
/// index at all): this is a reading/comprehension format, not a quiz.
public struct QAItem: Identifiable, Codable, Hashable {
    public let id: String
    public let question: String
    public let topics: [String]
    public let explanation: String
    public let example: String
    public let keyTakeaways: [String]

    public init(
        id: String,
        question: String,
        topics: [String] = [],
        explanation: String,
        example: String,
        keyTakeaways: [String] = []
    ) {
        self.id = id
        self.question = question
        self.topics = topics
        self.explanation = explanation
        self.example = example
        self.keyTakeaways = keyTakeaways
    }
}
