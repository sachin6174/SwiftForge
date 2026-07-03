import SwiftUI

public struct SwiftPracticeDescriptionView: View {
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
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.15))
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
                    
                    if let networkUrl = question.networkUrl {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Target API Endpoint:")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(networkUrl)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.blue)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.25))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "square.dashed")
                            .font(.largeTitle)
                        Text("Select a network question")
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
}
