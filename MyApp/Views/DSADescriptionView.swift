import SwiftUI

public struct DSADescriptionView: View {
    let question: Question?
    
    public init(question: Question?) {
        self.question = question
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let question = question {
                    // ── Title & Meta Section ──
                    VStack(alignment: .leading, spacing: 10) {
                        Text(question.title)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        // Metadata chips
                        HStack(spacing: 8) {
                            // Difficulty Badge
                            Text(question.difficulty)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(getDifficultyColor(question.difficulty))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(getDifficultyColor(question.difficulty).opacity(0.12))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(getDifficultyColor(question.difficulty).opacity(0.25), lineWidth: 0.75)
                                )
                            
                            // Topics Chip Group
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(question.topics, id: \.self) { topic in
                                        Text(topic)
                                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                            .foregroundColor(Color.white.opacity(0.65))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.white.opacity(0.04))
                                            .cornerRadius(5)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 5)
                                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 6)
                    
                    // ── API Endpoint Details (Swift Network Practice only) ──
                    if let networkUrl = question.networkUrl {
                        let isPost = question.id == "post_todo"
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("API ENDPOINT DETAILED SCHEMA")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(Color.white.opacity(0.35))
                                .tracking(0.5)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Text(isPost ? "POST" : "GET")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(isPost ? Color.orange : Color.green)
                                        .cornerRadius(4)
                                        .shadow(color: (isPost ? Color.orange : Color.green).opacity(0.4), radius: 4)
                                    
                                    Text(networkUrl)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.cyan)
                                        .lineLimit(1)
                                        .textSelection(.enabled)
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.06))
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(isPost ? "REQUEST DATA PAYLOAD" : "EXPECTED RESPONSE STRUCTURE")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(Color.white.opacity(0.45))
                                    
                                    Text(isPost ? """
                                    {
                                      "userId": 1,
                                      "title": "Learn Swift Architecture",
                                      "completed": true
                                    }
                                    """ : """
                                    {
                                      "userId": 1,
                                      "id": 1,
                                      "title": "delectus aut autem",
                                      "completed": false
                                    }
                                    """)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color.cyan.opacity(0.85))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.25))
                                    .cornerRadius(6)
                                }
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 0.75)
                            )
                        }
                    }

                    // ── Challenge Body Description ──
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PROBLEM DESCRIPTION")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(Color.white.opacity(0.35))
                            .tracking(0.5)
                        
                        Text(question.description)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.85))
                            .lineSpacing(5)
                            .textSelection(.enabled)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.08))
                    
                    // ── Interview Tips Section ──
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 14))
                                .shadow(color: .yellow.opacity(0.5), radius: 4)
                            Text("Interview & Architecture Focus:")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            switch question.category {
                            case "swiftPractice":
                                ConstraintBullet(text: "Ensure URLSession tasks are resumed using task.resume() call.")
                                ConstraintBullet(text: "Handle network & decoding errors using clean do-catch syntax blocks.")
                                ConstraintBullet(text: "Use DispatchSemaphore or Task groups to await asynchronous call execution.")
                            case "machineRound":
                                ConstraintBullet(text: "Clarify the requirements and constraints out loud before writing any code.")
                                ConstraintBullet(text: "Call out thread-safety, concurrency, and failure-mode trade-offs explicitly.")
                                ConstraintBullet(text: "Design for the stated scale first — correctness and clarity beat cleverness.")
                            default:
                                ConstraintBullet(text: "Clarify input size limits and expected edge conditions upfront.")
                                ConstraintBullet(text: "State the optimal Time & Space Complexity targets before coding.")
                                ConstraintBullet(text: "Dry run your logical index transitions with base arrays first.")
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.05), lineWidth: 0.75)
                        )
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 32))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Select a challenge to display details")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                }
            }
            .padding(18)
        }
        .id(question?.id ?? "empty")
        .background(Color(red: 0.08, green: 0.09, blue: 0.12))
    }
    
    private func getDifficultyColor(_ diff: String) -> Color {
        switch diff.lowercased() {
        case "easy": return Color(red: 0.3, green: 0.8, blue: 0.4)
        case "medium": return Color(red: 1.0, green: 0.6, blue: 0.1)
        case "hard": return Color(red: 1.0, green: 0.25, blue: 0.3)
        default: return .blue
        }
    }
}
