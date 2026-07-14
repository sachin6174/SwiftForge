import Foundation

/// A full take-home/portfolio project spec — the kind of "build a whole app"
/// assignment real interviews hand out, as opposed to a single-function DSA
/// problem or a scoped Machine Round exercise. Deliberately has no
/// templateCode/solutionCode/testHarness: this app's console runner executes
/// single-file Swift scripts, not multi-view SwiftUI/UIKit apps, so a
/// project is read-only reference material (like Q&A), not something graded
/// by running it.
public struct ProjectItem: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    /// Where the assignment came from — a company's take-home brief (kept
    /// exactly as named, matching this app's existing convention of
    /// attributing Machine Round questions to the assessing company, e.g.
    /// "Honeywell-style") or a self-directed practice project.
    public let source: String
    public let topics: [String]
    public let difficulty: String
    public let description: String

    public init(
        id: String,
        title: String,
        source: String,
        topics: [String] = [],
        difficulty: String,
        description: String
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.topics = topics
        self.difficulty = difficulty
        self.description = description
    }
}
