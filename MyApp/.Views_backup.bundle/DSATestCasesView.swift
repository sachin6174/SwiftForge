import SwiftUI

public struct DSATestCasesView: View {
    @ObservedObject var viewModel: DSAPracticeViewModel
    
    public init(viewModel: DSAPracticeViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suite Results")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, 12)
                .padding(.horizontal, 12)
            
            if viewModel.testcaseResults.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .frame(width: 36, height: 36)
                        .foregroundColor(.orange.opacity(0.6))
                    Text("Run suite to test code.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.testcaseResults) { result in
                            Button(action: {
                                viewModel.selectedTestCaseIndex = result.index
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: result.isPass ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(result.isPass ? .green : .red)
                                        .font(.caption)
                                    Text("C\(result.index)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(viewModel.selectedTestCaseIndex == result.index ? Color.orange.opacity(0.25) : Color.white.opacity(0.04))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(viewModel.selectedTestCaseIndex == result.index ? Color.orange : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 12)
                }
                
                Divider()
                    .background(Color.gray.opacity(0.2))
                    .padding(.horizontal, 12)
                
                if viewModel.selectedTestCaseIndex < viewModel.testcaseResults.count {
                    let result = viewModel.testcaseResults[viewModel.selectedTestCaseIndex]
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(result.name)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Spacer()
                                Text(result.time)
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)
                            }
                            
                            // DYNAMIC VISUALIZERS DEPENDING ON PROBLEM ID
                            VStack(alignment: .leading, spacing: 6) {
                                if viewModel.currentQuestion?.id == "climb_stairs" {
                                    let stairsN = getStairsInput(for: result.index)
                                    StaircaseVisualizerView(steps: stairsN)
                                } else {
                                    let testCaseInput = getTestCaseMatrix(for: result.index)
                                    Text("Matrix Visualizer:")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                        .fontWeight(.semibold)
                                    MatrixVisualizerView(matrix: testCaseInput)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Expected")
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray)
                                    Text(result.expected)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color.green.opacity(0.08))
                                .cornerRadius(6)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Output")
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray)
                                    Text(result.output)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(result.isPass ? .green : .red)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(result.isPass ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
                                .cornerRadius(6)
                            }
                            
                            if let error = result.error {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Error Log")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.red.opacity(0.8))
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.red.opacity(0.05))
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                }
            }
        }
        .background(Color(red: 0.1, green: 0.11, blue: 0.14))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    func getTestCaseMatrix(for index: Int) -> [[Character]] {
        let matrices: [[[Character]]] = [
            [["1","0","1","0","0"],["1","0","1","1","1"],["1","1","1","1","1"],["1","0","0","1","0"]],
            [["0","1"],["1","0"]],
            [["0"]],
            [],
            [["1", "1", "1"]],
            [["0","0"],["0","0"]],
            [["1","1","1"],["1","1","1"],["1","1","1"]]
        ]
        if index >= 0 && index < matrices.count {
            return matrices[index]
        }
        return []
    }
    
    func getStairsInput(for index: Int) -> Int {
        let inputs = [2, 3, 5, 1, 10]
        if index >= 0 && index < inputs.count {
            return inputs[index]
        }
        return 1
    }
}

// MARK: - Staircase Visualizer Component
struct StaircaseVisualizerView: View {
    let steps: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Staircase Visualizer:")
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .fontWeight(.semibold)
            
            HStack(alignment: .bottom, spacing: 6) {
                // Limit maximum steps drawn visually so it doesn't overflow
                let maxStepsToDraw = min(steps, 6)
                
                ForEach(1...max(1, maxStepsToDraw), id: \.self) { step in
                    VStack {
                        Spacer()
                        
                        Text("S\(step)")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 24, height: CGFloat(step) * 15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.cyan, lineWidth: 1)
                            )
                            .shadow(color: Color.blue.opacity(0.4), radius: 3)
                    }
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("DP Recurrence: f(n) = f(n-1) + f(n-2)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.cyan)
                    .bold()
                
                Text("Paths to Step \(steps): Sum of paths from step \(steps-1) (1-step hop) and step \(steps-2) (2-step hop).")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(6)
            .background(Color.white.opacity(0.02))
            .cornerRadius(4)
        }
    }
}
