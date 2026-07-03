import Foundation

public struct UserActivity: Codable {
    public var solvedQuestionIds: Set<String>
    public var draftCodes: [String: String]
    public var streak: Int
    public var lastActiveDate: String? // "YYYY-MM-DD" format
    public var activityHistory: [String] // "YYYY-MM-DD" array of active days
    public var totalRuns: Int
    
    public init(
        solvedQuestionIds: Set<String> = [],
        draftCodes: [String: String] = [:],
        streak: Int = 0,
        lastActiveDate: String? = nil,
        activityHistory: [String] = [],
        totalRuns: Int = 0
    ) {
        self.solvedQuestionIds = solvedQuestionIds
        self.draftCodes = draftCodes
        self.streak = streak
        self.lastActiveDate = lastActiveDate
        self.activityHistory = activityHistory
        self.totalRuns = totalRuns
    }
}
