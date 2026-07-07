import SwiftUI

public struct DSATestCasesView: View {
    @ObservedObject var viewModel: DSAPracticeViewModel
    
    public init(viewModel: DSAPracticeViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suite Results")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 14)
                .padding(.horizontal, 14)
            
            if viewModel.currentQuestion?.category == "swiftPractice" {
                VStack(spacing: 16) {
                    Image(systemName: "globe.americas.fill")
                        .resizable()
                        .frame(width: 44, height: 44)
                        .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Color.blue.opacity(0.4), radius: 6)
                    
                    Text("Swift Network Practice")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("This challenge executes network requests via URLSession. Click 'Run Suite' below to perform transactions and inspect the logs in the console.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    if let url = viewModel.currentQuestion?.networkUrl {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.system(size: 10))
                                .foregroundColor(.cyan)
                            Text(url)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.cyan)
                                .bold()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.blue.opacity(0.25), lineWidth: 0.75)
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.testcaseResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.orange.opacity(0.65))
                        .shadow(color: Color.orange.opacity(0.3), radius: 6)
                    Text("Run suite to test reference cases.")
                        .foregroundColor(Color.white.opacity(0.4))
                        .font(.system(size: 11, weight: .bold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let allPassed = viewModel.testcaseResults.allSatisfy { $0.isPass }
                if allPassed {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                        Text("All \(viewModel.testcaseResults.count) test cases passed")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .overlay(Rectangle().fill(Color.green.opacity(0.3)).frame(height: 0.75), alignment: .bottom)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Testcase buttons selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.testcaseResults) { result in
                            Button(action: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    viewModel.selectedTestCaseIndex = result.index
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: result.isPass ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(result.isPass ? .green : .red)
                                        .font(.system(size: 10, weight: .bold))
                                    Text("Case \(result.index)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(viewModel.selectedTestCaseIndex == result.index ? Color.orange.opacity(0.18) : Color.white.opacity(0.04))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(viewModel.selectedTestCaseIndex == result.index ? Color.orange.opacity(0.6) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.94))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, allPassed ? 10 : 0)
                }

                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.horizontal, 14)
                
                if viewModel.selectedTestCaseIndex < viewModel.testcaseResults.count {
                    let result = viewModel.testcaseResults[viewModel.selectedTestCaseIndex]
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text(result.name)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("Time: " + result.time)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                            
                            // Visualizer selection based on problem ID
                            VStack(alignment: .leading, spacing: 8) {
                                switch viewModel.currentQuestion?.id {
                                case "two_sum":
                                    TwoSumVisualizerView(index: result.index)
                                case "valid_parentheses":
                                    ValidParenthesesVisualizerView(index: result.index)
                                case "reverse_linked_list":
                                    LinkedListVisualizerView(index: result.index)
                                case "rod_cutting":
                                    RodCuttingVisualizerView(index: result.index)
                                case "climb_stairs":
                                    let stairsN = getStairsInput(for: result.index)
                                    StaircaseVisualizerView(steps: stairsN)
                                default:
                                    let testCaseInput = getTestCaseMatrix(for: result.index)
                                    Text("Grid Matrix Output:")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(Color.white.opacity(0.4))
                                    MatrixVisualizerView(matrix: testCaseInput)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                            
                            // Expected vs Output display cards
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Expected Output")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(Color.white.opacity(0.45))
                                    Text(result.expected)
                                        .font(.system(size: 12, weight: .black, design: .monospaced))
                                        .foregroundColor(.green)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color.green.opacity(0.08))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.green.opacity(0.25), lineWidth: 0.75)
                                )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Actual Output")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(Color.white.opacity(0.45))
                                    Text(result.output)
                                        .font(.system(size: 12, weight: .black, design: .monospaced))
                                        .foregroundColor(result.isPass ? .green : .red)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(result.isPass ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke((result.isPass ? Color.green : Color.red).opacity(0.25), lineWidth: 0.75)
                                )
                            }
                            
                            if let error = result.error {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Execution Error Details")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.red.opacity(0.85))
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.red.opacity(0.05))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.red.opacity(0.2), lineWidth: 0.75)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
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
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color.white.opacity(0.4))
            
            HStack(alignment: .bottom, spacing: 8) {
                let maxStepsToDraw = min(steps, 6)
                
                ForEach(1...max(1, maxStepsToDraw), id: \.self) { step in
                    VStack(spacing: 4) {
                        Spacer()
                        
                        Text("Step \(step)")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.6))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 28, height: CGFloat(step) * 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.cyan.opacity(0.5), lineWidth: 0.75)
                            )
                            .shadow(color: Color.blue.opacity(0.35), radius: 4, x: 0, y: 1)
                    }
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Recurrence Form: f(n) = f(n-1) + f(n-2)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                Text("Ways to Step \(steps) is the sum of ways from step \(steps-1) and step \(steps-2).")
                    .font(.system(size: 8))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.02))
            .cornerRadius(6)
        }
    }
}

// MARK: - Two Sum Visualizer Component
struct TwoSumVisualizerView: View {
    let index: Int
    
    var body: some View {
        let sampleCases: [(nums: [Int], target: Int, match: [Int])] = [
            ([2, 7, 11, 15], 9, [0, 1]),
            ([3, 2, 4], 6, [1, 2]),
            ([3, 3], 6, [0, 1])
        ]
        let item = (index >= 0 && index < sampleCases.count) ? sampleCases[index] : sampleCases[0]
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Hash Map Target Finder")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.4))
                Spacer()
                Text("Target: \(item.target)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2.5)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(5)
            }
            
            HStack(spacing: 10) {
                ForEach(0..<item.nums.count, id: \.self) { i in
                    let isMatched = item.match.contains(i)
                    VStack(spacing: 5) {
                        Text("[\(i)]")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(isMatched ? .orange : Color.white.opacity(0.35))
                        
                        Text("\(item.nums[i])")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isMatched 
                                        ? LinearGradient(colors: [Color.orange.opacity(0.3), Color.red.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing) 
                                        : LinearGradient(colors: [Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isMatched ? Color.orange : Color.white.opacity(0.08), lineWidth: isMatched ? 1.5 : 0.75)
                            )
                            .shadow(color: isMatched ? Color.orange.opacity(0.3) : Color.clear, radius: 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(12)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
        }
    }
}

// MARK: - Valid Parentheses Visualizer Component
struct ValidParenthesesVisualizerView: View {
    let index: Int
    
    var body: some View {
        let sampleCases: [(s: String, isValid: Bool)] = [
            ("()", true),
            ("()[]{}", true),
            ("(]", false),
            ("([)]", false),
            ("{[]}", true)
        ]
        let item = (index >= 0 && index < sampleCases.count) ? sampleCases[index] : sampleCases[0]
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Parentheses Stack States")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.4))
                Spacer()
                Text(item.isValid ? "VALID SYMMETRY" : "INVALID SYMMETRY")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(item.isValid ? .green : .red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((item.isValid ? Color.green : Color.red).opacity(0.12))
                    .cornerRadius(4)
            }
            
            HStack(spacing: 8) {
                ForEach(Array(item.s.enumerated()), id: \.offset) { _, char in
                    Text(String(char))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .frame(width: 32, height: 34)
                        .background(Color.cyan.opacity(0.12))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 0.8)
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(12)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
        }
    }
}

// MARK: - Linked List Visualizer Component
struct LinkedListVisualizerView: View {
    let index: Int
    
    var body: some View {
        let sampleCases: [[Int]] = [
            [1, 2, 3, 4, 5],
            [1, 2],
            []
        ]
        let nodes = (index >= 0 && index < sampleCases.count) ? sampleCases[index] : sampleCases[0]
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Linked List Visual Representation:")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color.white.opacity(0.4))
            
            if nodes.isEmpty {
                Text("nil (List is Empty)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(0..<nodes.count, id: \.self) { i in
                            HStack(spacing: 6) {
                                Text("\(nodes[i])")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        LinearGradient(colors: [Color.purple.opacity(0.4), Color.indigo.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.purple.opacity(0.6), lineWidth: 1)
                                    )
                                    .shadow(color: Color.purple.opacity(0.35), radius: 3)
                                
                                if i < nodes.count - 1 {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.purple.opacity(0.7))
                                }
                            }
                        }
                        Text("-> nil")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.2))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Rod Cutting Visualizer Component
struct RodCuttingVisualizerView: View {
    let index: Int
    
    var body: some View {
        let sampleCases: [(prices: [Int], length: Int, expected: Int)] = [
            ([0, 1, 5, 8, 9, 10, 17, 17, 20], 8, 22),
            ([0, 3, 5, 8, 9, 10, 17, 17, 20], 8, 24),
            ([0, 3], 1, 3),
            ([0, 1, 1, 1, 100], 4, 100),
            ([0, 0, 0, 0], 3, 0),
            ([0], 0, 0),
            ([0, 2, 5, 9, 10, 15, 17, 20, 24, 30], 9, 30)
        ]
        let item = (index >= 0 && index < sampleCases.count) ? sampleCases[index] : sampleCases[0]
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DP Knapsack Revenue Visualizer")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.4))
                Spacer()
                Text("Max Revenue: $\(item.expected)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2.5)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(5)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Pricing Reference: " + item.prices.description)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.cyan)
                
                Text("Available Rod Length (N): \(item.length)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
        }
    }
}
