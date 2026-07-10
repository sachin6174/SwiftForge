import Foundation
import Combine

public enum PracticeTab: String, CaseIterable, Identifiable {
    case dsa = "DSA Practice"
    case swiftPractice = "Swift Practice"
    case mcq = "MCQ Practice"
    case machineRound = "Machine Round"

    public var id: String { rawValue }
}

@MainActor
public class AppState: ObservableObject {
    @Published public var questions: [Question] = []
    @Published public var mcqQuestions: [MCQQuestion] = []
    @Published public var selectedDSAQuestion: Question? {
        didSet {
            guard isRestoringSelection == false, oldValue?.id != selectedDSAQuestion?.id else { return }
            userActivity.lastSelectedDSAQuestionId = selectedDSAQuestion?.id
            saveActivity()
        }
    }
    @Published public var selectedSwiftQuestion: Question? {
        didSet {
            guard isRestoringSelection == false, oldValue?.id != selectedSwiftQuestion?.id else { return }
            userActivity.lastSelectedSwiftQuestionId = selectedSwiftQuestion?.id
            saveActivity()
        }
    }
    @Published public var selectedMCQQuestion: MCQQuestion? {
        didSet {
            guard isRestoringSelection == false, oldValue?.id != selectedMCQQuestion?.id else { return }
            userActivity.lastSelectedMCQQuestionId = selectedMCQQuestion?.id
            saveActivity()
        }
    }
    @Published public var selectedMachineRoundQuestion: Question? {
        didSet {
            guard isRestoringSelection == false, oldValue?.id != selectedMachineRoundQuestion?.id else { return }
            userActivity.lastSelectedMachineRoundQuestionId = selectedMachineRoundQuestion?.id
            saveActivity()
        }
    }
    @Published public var activeTab: PracticeTab = .dsa {
        didSet {
            guard isRestoringSelection == false, oldValue != activeTab else { return }
            userActivity.lastActiveTab = activeTab.rawValue
            saveActivity()
        }
    }
    @Published public var userActivity = UserActivity()

    // Suppresses the didSet persistence hooks above while loadData() is
    // restoring a PREVIOUSLY-persisted selection — without this, restoring
    // the saved question on launch would immediately re-trigger a redundant
    // save, and (more importantly) if the saved id no longer resolves to a
    // real question, silently overwrite the just-loaded selection with
    // whatever fallback `nil`/`.first` this same assignment produces.
    private var isRestoringSelection = false
    
    public var dsaQuestions: [Question] {
        questions.filter { $0.category == "dsa" }
    }
    
    public var swiftQuestions: [Question] {
        questions.filter { $0.category == "swiftPractice" }
    }

    public var machineRoundQuestions: [Question] {
        questions.filter { $0.category == "machineRound" }
    }

    public var mcqAnsweredCount: Int {
        mcqQuestions.filter { userActivity.mcqAnsweredIds.contains($0.id) }.count
    }

    public var mcqCorrectCount: Int {
        mcqQuestions.filter { userActivity.mcqCorrectIds.contains($0.id) }.count
    }
    
    private let databaseService: DatabaseServiceProtocol
    private let activityService: UserActivityServiceProtocol
    
    public init(
        databaseService: DatabaseServiceProtocol? = nil,
        activityService: UserActivityServiceProtocol? = nil
    ) {
        self.databaseService = databaseService ?? DatabaseService()
        self.activityService = activityService ?? UserActivityService()
        self.loadData()
    }
    
    public func loadData() {
        self.questions = databaseService.loadQuestions()
        self.mcqQuestions = databaseService.loadMCQQuestions()
        self.userActivity = activityService.loadActivity()
        
        // Sanitize drafts: if draft matches solutionCode or invalid residual output, purge it!
        for q in self.questions {
            if let draft = self.userActivity.draftCodes[q.id] {
                let cleanDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanSol = q.solutionCode.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if cleanDraft == cleanSol || draft.contains("\"Completed") {
                    self.userActivity.draftCodes.removeValue(forKey: q.id)
                }
            }
        }
        
        isRestoringSelection = true
        if let savedTab = userActivity.lastActiveTab, let tab = PracticeTab(rawValue: savedTab) {
            self.activeTab = tab
        }
        if let savedId = userActivity.lastSelectedDSAQuestionId {
            self.selectedDSAQuestion = dsaQuestions.first(where: { $0.id == savedId }) ?? dsaQuestions.first
        } else {
            self.selectedDSAQuestion = dsaQuestions.first
        }
        if let savedId = userActivity.lastSelectedSwiftQuestionId {
            self.selectedSwiftQuestion = swiftQuestions.first(where: { $0.id == savedId }) ?? swiftQuestions.first
        } else {
            self.selectedSwiftQuestion = swiftQuestions.first
        }
        if let savedId = userActivity.lastSelectedMCQQuestionId {
            self.selectedMCQQuestion = mcqQuestions.first(where: { $0.id == savedId }) ?? mcqQuestions.first
        } else {
            self.selectedMCQQuestion = mcqQuestions.first
        }
        if let savedId = userActivity.lastSelectedMachineRoundQuestionId {
            self.selectedMachineRoundQuestion = machineRoundQuestions.first(where: { $0.id == savedId }) ?? machineRoundQuestions.first
        } else {
            self.selectedMachineRoundQuestion = machineRoundQuestions.first
        }
        isRestoringSelection = false

        // Log activity for today on launch
        self.logActivity()
    }
    
    private var debounceSaveTask: Task<Void, Never>?

    public func saveActivity() {
        activityService.saveActivity(userActivity)
    }

    public func updateDraft(questionId: String, code: String) {
        userActivity.draftCodes[questionId] = code

        // Debounce: cancel previous pending save and schedule a new one
        debounceSaveTask?.cancel()
        debounceSaveTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 800_000_000) // 0.8 s
                self?.saveActivity()
            } catch {
                // Task was cancelled — no-op
            }
        }
    }
    
    public func markQuestionSolved(questionId: String) {
        userActivity.solvedQuestionIds.insert(questionId)
        saveActivity()
    }

    /// Records an attempt at an MCQ question. Always marks it "answered"
    /// (for progress display); only adds it to "correct" if `isCorrect` —
    /// re-answering a previously-missed question correctly upgrades it, but
    /// re-answering a previously-correct one incorrectly does NOT revoke the
    /// earlier credit (matches how `solvedQuestionIds` never un-solves a
    /// DSA question either).
    public func recordMCQAnswer(questionId: String, isCorrect: Bool) {
        userActivity.mcqAnsweredIds.insert(questionId)
        if isCorrect {
            userActivity.mcqCorrectIds.insert(questionId)
        }
        saveActivity()
    }
    
    public func incrementRunCount() {
        userActivity.totalRuns += 1
        saveActivity()
    }
    
    public func logActivity() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // Explicit timezone prevents streak miscounts when user changes timezone
        formatter.timeZone = TimeZone.current
        let todayStr = formatter.string(from: Date())

        if !userActivity.activityHistory.contains(todayStr) {
            userActivity.activityHistory.append(todayStr)
            // Cap history to last 365 days to prevent unbounded growth
            if userActivity.activityHistory.count > 365 {
                userActivity.activityHistory = Array(userActivity.activityHistory.suffix(365))
            }
        }
        
        if let lastActive = userActivity.lastActiveDate {
            if lastActive != todayStr {
                if let lastDate = formatter.date(from: lastActive) {
                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.day], from: lastDate, to: Date())
                    if components.day == 1 {
                        userActivity.streak += 1
                    } else if (components.day ?? 0) > 1 {
                        userActivity.streak = 1
                    }
                } else {
                    userActivity.streak = 1
                }
                userActivity.lastActiveDate = todayStr
            }
        } else {
            userActivity.streak = 1
            userActivity.lastActiveDate = todayStr
        }
        
        saveActivity()
    }
}
