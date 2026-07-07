import Foundation

public struct Question: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let category: String
    public let difficulty: String
    public let topics: [String]
    public let description: String
    public let templateCode: String
    public let solutionCode: String
    public let testHarness: String?
    public let networkUrl: String?
    public let alternateSolutionTitle: String?
    public let alternateSolutionCode: String?

    public init(id: String, title: String, category: String, difficulty: String, topics: [String], description: String, templateCode: String, solutionCode: String, testHarness: String? = nil, networkUrl: String? = nil, alternateSolutionTitle: String? = nil, alternateSolutionCode: String? = nil) {
        self.id = id
        self.title = title
        self.category = category
        self.difficulty = difficulty
        self.topics = topics
        self.description = description
        self.templateCode = templateCode
        self.solutionCode = solutionCode
        self.testHarness = testHarness
        self.networkUrl = networkUrl
        self.alternateSolutionTitle = alternateSolutionTitle
        self.alternateSolutionCode = alternateSolutionCode
    }
}
