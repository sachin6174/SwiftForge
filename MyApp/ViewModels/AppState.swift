import Foundation
import Combine

public enum PracticeTab: String, CaseIterable, Identifiable {
    case dsa = "DSA Practice"
    case swiftPractice = "Swift Practice"
    
    public var id: String { rawValue }
}

@MainActor
public class AppState: ObservableObject {
    @Published public var questions: [Question] = []
    @Published public var selectedDSAQuestion: Question?
    @Published public var selectedSwiftQuestion: Question?
    @Published public var activeTab: PracticeTab = .dsa
    @Published public var userActivity = UserActivity()
    
    public var dsaQuestions: [Question] {
        questions.filter { $0.category == "dsa" }
    }
    
    public var swiftQuestions: [Question] {
        questions.filter { $0.category == "swiftPractice" }
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
        self.userActivity = activityService.loadActivity()
        
        // Sanitize drafts: if draft matches solutionCode or is missing return statement, purge it!
        for q in self.questions {
            if let draft = self.userActivity.draftCodes[q.id] {
                let cleanDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanSol = q.solutionCode.trimmingCharacters(in: .whitespacesAndNewlines)
                let missingReturn = q.templateCode.contains("return ") && !cleanDraft.contains("return ")
                
                if cleanDraft == cleanSol || draft.contains("\"Completed") || missingReturn {
                    self.userActivity.draftCodes.removeValue(forKey: q.id)
                }
            }
        }
        
        self.selectedDSAQuestion = dsaQuestions.first
        self.selectedSwiftQuestion = swiftQuestions.first
        
        // Log activity for today on launch
        self.logActivity()
    }
    
    private var saveWorkItem: DispatchWorkItem?
    
    public func saveActivity() {
        activityService.saveActivity(userActivity)
    }
    
    public func updateDraft(questionId: String, code: String) {
        userActivity.draftCodes[questionId] = code
        
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.saveActivity()
            }
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: item)
    }
    
    public func markQuestionSolved(questionId: String) {
        userActivity.solvedQuestionIds.insert(questionId)
        saveActivity()
    }
    
    public func incrementRunCount() {
        userActivity.totalRuns += 1
        saveActivity()
    }
    
    public func logActivity() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        
        if !userActivity.activityHistory.contains(todayStr) {
            userActivity.activityHistory.append(todayStr)
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
