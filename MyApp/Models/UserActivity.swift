import Foundation

public struct UserActivity: Codable {
    public var solvedQuestionIds: Set<String>
    public var draftCodes: [String: String]
    public var streak: Int
    public var lastActiveDate: String? // "YYYY-MM-DD" format
    public var activityHistory: [String] // "YYYY-MM-DD" array of active days
    public var totalRuns: Int
    // Resume-where-you-left-off: which question/tab was open last, so
    // relaunching the app doesn't silently jump back to the first question
    // in each tab and discard the user's place (drafts were already
    // preserved per-question; the selection itself was not).
    public var lastSelectedDSAQuestionId: String?
    public var lastSelectedSwiftQuestionId: String?
    public var lastActiveTab: String?
    // MCQ practice progress — separate from solvedQuestionIds since an MCQ
    // "attempt" and a "correct answer" are distinct states worth tracking
    // independently (e.g. showing "12 answered, 9 correct" rather than just
    // a single solved/unsolved bit).
    public var mcqAnsweredIds: Set<String>
    public var mcqCorrectIds: Set<String>
    public var lastSelectedMCQQuestionId: String?
    public var lastSelectedMachineRoundQuestionId: String?
    // Q&A practice progress — tracked as "viewed" (opened at least once),
    // there being no right/wrong answer to grade here, unlike MCQ.
    public var qaViewedIds: Set<String>
    public var lastSelectedQAItemId: String?

    public init(
        solvedQuestionIds: Set<String> = [],
        draftCodes: [String: String] = [:],
        streak: Int = 0,
        lastActiveDate: String? = nil,
        activityHistory: [String] = [],
        totalRuns: Int = 0,
        lastSelectedDSAQuestionId: String? = nil,
        lastSelectedSwiftQuestionId: String? = nil,
        lastActiveTab: String? = nil,
        mcqAnsweredIds: Set<String> = [],
        mcqCorrectIds: Set<String> = [],
        lastSelectedMCQQuestionId: String? = nil,
        lastSelectedMachineRoundQuestionId: String? = nil,
        qaViewedIds: Set<String> = [],
        lastSelectedQAItemId: String? = nil
    ) {
        self.solvedQuestionIds = solvedQuestionIds
        self.draftCodes = draftCodes
        self.streak = streak
        self.lastActiveDate = lastActiveDate
        self.activityHistory = activityHistory
        self.totalRuns = totalRuns
        self.lastSelectedDSAQuestionId = lastSelectedDSAQuestionId
        self.lastSelectedSwiftQuestionId = lastSelectedSwiftQuestionId
        self.lastActiveTab = lastActiveTab
        self.mcqAnsweredIds = mcqAnsweredIds
        self.mcqCorrectIds = mcqCorrectIds
        self.lastSelectedMCQQuestionId = lastSelectedMCQQuestionId
        self.lastSelectedMachineRoundQuestionId = lastSelectedMachineRoundQuestionId
        self.qaViewedIds = qaViewedIds
        self.lastSelectedQAItemId = lastSelectedQAItemId
    }

    // Custom decoding: `mcqAnsweredIds`/`mcqCorrectIds` are non-optional
    // Sets, but every ALREADY-persisted user_activity.json on disk predates
    // them and has no such keys at all. Swift's auto-synthesized Decodable
    // only defaults MISSING keys to nil for genuinely Optional properties —
    // for a non-optional Set it would throw `keyNotFound` instead, which
    // would make loadActivity() fail entirely and silently reset the
    // user's ENTIRE activity (streak, solved questions, drafts) back to a
    // blank UserActivity(). decodeIfPresent + `?? []` here keeps every
    // field backward-compatible with old files, matching what the
    // already-Optional fields get for free.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        solvedQuestionIds = try container.decodeIfPresent(Set<String>.self, forKey: .solvedQuestionIds) ?? []
        draftCodes = try container.decodeIfPresent([String: String].self, forKey: .draftCodes) ?? [:]
        streak = try container.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        lastActiveDate = try container.decodeIfPresent(String.self, forKey: .lastActiveDate)
        activityHistory = try container.decodeIfPresent([String].self, forKey: .activityHistory) ?? []
        totalRuns = try container.decodeIfPresent(Int.self, forKey: .totalRuns) ?? 0
        lastSelectedDSAQuestionId = try container.decodeIfPresent(String.self, forKey: .lastSelectedDSAQuestionId)
        lastSelectedSwiftQuestionId = try container.decodeIfPresent(String.self, forKey: .lastSelectedSwiftQuestionId)
        lastActiveTab = try container.decodeIfPresent(String.self, forKey: .lastActiveTab)
        mcqAnsweredIds = try container.decodeIfPresent(Set<String>.self, forKey: .mcqAnsweredIds) ?? []
        mcqCorrectIds = try container.decodeIfPresent(Set<String>.self, forKey: .mcqCorrectIds) ?? []
        lastSelectedMCQQuestionId = try container.decodeIfPresent(String.self, forKey: .lastSelectedMCQQuestionId)
        lastSelectedMachineRoundQuestionId = try container.decodeIfPresent(String.self, forKey: .lastSelectedMachineRoundQuestionId)
        qaViewedIds = try container.decodeIfPresent(Set<String>.self, forKey: .qaViewedIds) ?? []
        lastSelectedQAItemId = try container.decodeIfPresent(String.self, forKey: .lastSelectedQAItemId)
    }
}
