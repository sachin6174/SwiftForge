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
                    
                    if let networkUrl = question.networkUrl {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API ENDPOINT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(white: 0.5))
                            
                            HStack(spacing: 8) {
                                Text("GET")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(4)
                                
                                Text(networkUrl)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.cyan)
                                    .lineLimit(1)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.75)
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("EXPECTED JSON SCHEMA")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(white: 0.5))
                            
                            Text("""
                            {
                              "userId": 1,
                              "id": 1,
                              "title": "delectus aut autem",
                              "completed": false
                            }
                            """)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(white: 0.8))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.35))
                            .cornerRadius(6)
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
                        Text("Tips for Swift Interviews:")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            if question.category == "swiftPractice" {
                                ConstraintBullet(text: "Ensure URLSession tasks are resumed with task.resume().")
                                ConstraintBullet(text: "Handle decoding errors with do-catch blocks.")
                                ConstraintBullet(text: "Use DispatchSemaphore or async/await in CLI scripts to wait for response.")
                            } else {
                                ConstraintBullet(text: "Always clarify constraints first.")
                                ConstraintBullet(text: "Discuss time and space complexity upfront.")
                                ConstraintBullet(text: "Dry run your logic on basic test inputs.")
                            }
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
        .id(question?.id ?? "empty")
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
