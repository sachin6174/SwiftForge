import SwiftUI

public struct DashboardView: View {
    @ObservedObject var appState: AppState
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Banner
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Developer Dashboard")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        Text("Track your Swift compilation history, compiler executions, and question statuses.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.top, 24)
                
                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    // Solved Progress Card
                    VStack(alignment: .center, spacing: 12) {
                        Text("Questions Solved")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                        
                        let solved = appState.userActivity.solvedQuestionIds.count
                        let total = appState.questions.count
                        let ratio = total > 0 ? Double(solved) / Double(total) : 0.0
                        
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.06), lineWidth: 10)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(ratio))
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.green, Color.emerald],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                )
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                            
                            VStack(spacing: 2) {
                                Text("\(solved)/\(total)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Text("\(Int(ratio * 100))%")
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    
                    // Streak Card
                    VStack(alignment: .center, spacing: 12) {
                        Text("Preparation Streak")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                        
                        Image(systemName: "flame.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.orange.opacity(0.3), radius: 8)
                        
                        VStack(spacing: 2) {
                            Text("\(appState.userActivity.streak) Days")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Text("Last Active: \(appState.userActivity.lastActiveDate ?? "N/A")")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    
                    // Runs Card
                    VStack(alignment: .center, spacing: 12) {
                        Text("Total Executions")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                        
                        Image(systemName: "play.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.blue.opacity(0.3), radius: 8)
                        
                        VStack(spacing: 2) {
                            Text("\(appState.userActivity.totalRuns) Runs")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Text("Compiler runs logged")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                }
                
                // Contribution Map & Categories Split Side-By-Side
                HStack(alignment: .top, spacing: 16) {
                    ContributionGrid(activityHistory: appState.userActivity.activityHistory)
                        .frame(maxWidth: .infinity)
                    
                    // Category breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category Breakdown")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        let solvedDSA = appState.dsaQuestions.filter { appState.userActivity.solvedQuestionIds.contains($0.id) }.count
                        let totalDSA = appState.dsaQuestions.count
                        CategoryRow(title: "DSA Challenges", solved: solvedDSA, total: totalDSA, color: .orange)
                        
                        let solvedSwift = appState.swiftQuestions.filter { appState.userActivity.solvedQuestionIds.contains($0.id) }.count
                        let totalSwift = appState.swiftQuestions.count
                        CategoryRow(title: "Swift Networking & Basics", solved: solvedSwift, total: totalSwift, color: .blue)
                    }
                    .padding(16)
                    .frame(width: 320)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                }
                
                // Challenges solved list / recap
                VStack(alignment: .leading, spacing: 12) {
                    Text("Question Directory & Statuses")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 1) {
                        ForEach(appState.questions) { question in
                            let isSolved = appState.userActivity.solvedQuestionIds.contains(question.id)
                            HStack {
                                Image(systemName: isSolved ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSolved ? .green : .gray.opacity(0.4))
                                    .font(.system(size: 13))
                                
                                Text(question.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text(question.category == "dsa" ? "DSA" : "Swift")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(question.category == "dsa" ? .orange : .blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background((question.category == "dsa" ? Color.orange : Color.blue).opacity(0.12))
                                    .cornerRadius(4)
                                
                                Text(question.difficulty)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(difficultyColor(question.difficulty))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(difficultyColor(question.difficulty).opacity(0.12))
                                    .cornerRadius(4)
                                    .frame(width: 60, alignment: .trailing)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.01))
                        }
                    }
                    .background(Color.black.opacity(0.15))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 32)
        }
        .background(Color(red: 0.08, green: 0.09, blue: 0.12))
    }
    
    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "easy": return .green
        case "medium": return .orange
        case "hard": return .red
        default: return .gray
        }
    }
}

struct CategoryRow: View {
    let title: String
    let solved: Int
    let total: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Text("\(solved)/\(total)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            
            let progress = total > 0 ? Double(solved) / Double(total) : 0
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(progress), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}

struct ContributionGrid: View {
    let activityHistory: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activity Heatmap (Last 30 Days)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
            
            let days = getLast30Days()
            
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(16), spacing: 4), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { dateStr in
                    let isActive = activityHistory.contains(dateStr)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isActive ? Color.green : Color.white.opacity(0.08))
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    func getLast30Days() -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var list: [String] = []
        let calendar = Calendar.current
        for i in (0..<35).reversed() { // We display 35 blocks to fill grid nicely
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                list.append(formatter.string(from: date))
            }
        }
        return list
    }
}

extension Color {
    static let emerald = Color(red: 0.05, green: 0.75, blue: 0.4)
}
