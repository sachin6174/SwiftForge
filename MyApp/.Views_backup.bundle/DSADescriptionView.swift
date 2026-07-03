import SwiftUI

public struct DSADescriptionView: View {
    let question: Question?
    
    public init(question: Question?) {
        self.question = question
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let question = question {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(question.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            Text(question.difficulty)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(getDifficultyColor(question.difficulty))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(getDifficultyColor(question.difficulty).opacity(0.15))
                                .cornerRadius(4)
                            
                            Text("Topics: " + question.topics.joined(separator: ", "))
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Text(question.description)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(4)
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // Show interview tips
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tips for Interviews:")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            ConstraintBullet(text: "Always clarify constraints first.")
                            ConstraintBullet(text: "Discuss time and space complexity upfront.")
                            ConstraintBullet(text: "Dry run your logic on basic test inputs.")
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "square.dashed")
                            .font(.largeTitle)
                        Text("Select a question to begin")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.gray)
                }
            }
            .padding(16)
        }
        .background(Color(red: 0.12, green: 0.14, blue: 0.18))
    }
    
    private func getDifficultyColor(_ diff: String) -> Color {
        switch diff.lowercased() {
        case "easy": return .green
        case "medium": return .orange
        case "hard": return .red
        default: return .blue
        }
    }
}
