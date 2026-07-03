import Foundation
import Combine

@MainActor
public class AppState: ObservableObject {
    @Published public var selectedTab: Tab = .dsa
    @Published public var questions: [Question] = []
    
    @Published public var selectedDSAQuestion: Question?
    @Published public var selectedSwiftQuestion: Question?
    
    @Published public var userActivity = UserActivity()
    
    public var dsaQuestions: [Question] {
        questions.filter { $0.category == "dsa" }
    }
    
    public var swiftQuestions: [Question] {
        questions.filter { $0.category == "swiftPractice" }
    }
    
    public enum Tab {
        case dsa
        case swiftPractice
        case dashboard
    }
    
    private let databaseService: DatabaseServiceProtocol
    private let activityService: UserActivityServiceProtocol
    
    public init(
        databaseService: DatabaseServiceProtocol = DatabaseService(),
        activityService: UserActivityServiceProtocol = UserActivityService()
    ) {
        self.databaseService = databaseService
        self.activityService = activityService
        self.loadData()
    }
    
    public func loadData() {
        self.questions = databaseService.loadQuestions()
        self.userActivity = activityService.loadActivity()
        
        self.selectedDSAQuestion = dsaQuestions.first
        self.selectedSwiftQuestion = swiftQuestions.first
        
        // Log activity for today on launch
        self.logActivity()
    }
    
    public func saveActivity() {
        activityService.saveActivity(userActivity)
    }
    
    public func updateDraft(questionId: String, code: String) {
        userActivity.draftCodes[questionId] = code
        saveActivity()
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
