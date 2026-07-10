import Foundation

public struct MCQQuestion: Identifiable, Codable, Hashable {
    public let id: String
    public let question: String
    public let options: [String]
    public let correctAnswerIndex: Int
    public let topics: [String]

    public init(id: String, question: String, options: [String], correctAnswerIndex: Int, topics: [String] = []) {
        self.id = id
        self.question = question
        self.options = options
        self.correctAnswerIndex = correctAnswerIndex
        self.topics = topics
    }
}
