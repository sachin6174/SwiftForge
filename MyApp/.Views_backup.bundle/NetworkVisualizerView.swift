import SwiftUI

public struct NetworkVisualizerView: View {
    @ObservedObject var viewModel: SwiftPracticeViewModel
    
    public init(viewModel: SwiftPracticeViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network Monitor")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, 12)
                .padding(.horizontal, 12)
            
            VStack(spacing: 16) {
                // Pipeline diagram
                HStack(spacing: 8) {
                    VStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(viewModel.networkAnimationStep >= 1 ? .orange : .gray)
                        Text("App")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 45)
                    
                    LineConnector(isActive: viewModel.networkAnimationStep == 1 || viewModel.networkAnimationStep == 2, isForward: true)
                    
                    VStack(spacing: 4) {
                        Image(systemName: viewModel.networkAnimationStep == 2 ? "arrow.triangle.2.circlepath" : "cloud.fill")
                            .resizable()
                            .frame(width: 22, height: 16)
                            .foregroundColor(viewModel.networkAnimationStep >= 2 ? .blue : .gray)
                            .rotationEffect(.degrees(viewModel.networkAnimationStep == 2 ? 360 : 0))
                            .animation(viewModel.networkAnimationStep == 2 ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.networkAnimationStep)
                        Text("Server")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 50)
                    
                    LineConnector(isActive: viewModel.networkAnimationStep == 3 || viewModel.networkAnimationStep == 4, isForward: false)
                    
                    VStack(spacing: 4) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .resizable()
                            .frame(width: 18, height: 20)
                            .foregroundColor(viewModel.networkAnimationStep >= 4 ? .green : .gray)
                        Text("Model")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 45)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 6)
                .background(Color.black.opacity(0.2))
                .cornerRadius(8)
                
                Divider()
                    .background(Color.gray.opacity(0.2))
                
                HStack {
                    Text("Phase:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(getStatusText(for: viewModel.networkAnimationStep))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(getStatusColor(for: viewModel.networkAnimationStep))
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
                
                // Output parsed model card
                if let todo = viewModel.decodedTodo {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "curlybraces")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("struct Todo: Codable")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                            Spacer()
                            Text("Decoded")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.green.opacity(0.25))
                                .cornerRadius(3)
                        }
                        .padding(.bottom, 2)
                        
                        FieldRow(name: "userId", type: "Int", value: "\(todo.userId)")
                        FieldRow(name: "id", type: "Int", value: "\(todo.todoId)")
                        FieldRow(name: "title", type: "String", value: "\"\(todo.title)\"")
                        FieldRow(name: "completed", type: "Bool", value: "\(todo.completed)")
                    }
                    .padding(10)
                    .background(Color(red: 0.05, green: 0.05, blue: 0.07))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.green.opacity(0.03), radius: 4)
                } else if viewModel.isRunning {
                    VStack(spacing: 6) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                        Text("Decoding JSON...")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .frame(height: 100)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "network.badge.shield.half.filled")
                            .resizable()
                            .frame(width: 32, height: 28)
                            .foregroundColor(.gray.opacity(0.25))
                        Text("Run script to capture network")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                    .frame(height: 100)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color(red: 0.1, green: 0.11, blue: 0.14))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    func getStatusText(for step: Int) -> String {
        switch step {
        case 0: return "Idle"
        case 1: return "Sending GET..."
        case 2: return "Processing..."
        case 3: return "Receiving Payload..."
        case 4: return "Decoding to Model..."
        case 5: return "Done (200 OK)"
        default: return "Idle"
        }
    }
    
    func getStatusColor(for step: Int) -> Color {
        switch step {
        case 0: return .gray
        case 1, 2: return .orange
        case 3, 4: return .blue
        case 5: return .green
        default: return .gray
        }
    }
}
