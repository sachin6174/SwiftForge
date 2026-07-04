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
            
            if viewModel.currentQuestion?.category == "swiftPractice" {
                VStack(spacing: 12) {
                    Image(systemName: "globe.americas.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom))
                    
                    Text("Swift Network Practice")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("This question executes real HTTP requests via URLSession. Click 'Run Suite' below to fetch data and inspect terminal output.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    
                    if let url = viewModel.currentQuestion?.networkUrl {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.system(size: 10))
                                .foregroundColor(.cyan)
                            Text(url)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(6)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.testcaseResults.isEmpty {
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
                Text("Array & Hash Table Visualizer")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
                Text("Target: \(item.target)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(4)
            }
            
            HStack(spacing: 8) {
                ForEach(0..<item.nums.count, id: \.self) { i in
                    let isMatched = item.match.contains(i)
                    VStack(spacing: 4) {
                        Text("[\(i)]")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(isMatched ? .orange : .gray)
                        Text("\(item.nums[i])")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(isMatched ? .white : .gray)
                            .frame(width: 36, height: 36)
                            .background(isMatched ? Color.orange.opacity(0.3) : Color.white.opacity(0.05))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isMatched ? Color.orange : Color.white.opacity(0.1), lineWidth: isMatched ? 1.5 : 0.5)
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(10)
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
                Text("Stack String Visualizer")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
                Text(item.isValid ? "Balanced Stack" : "Unbalanced Stack")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(item.isValid ? .green : .red)
            }
            
            HStack(spacing: 6) {
                ForEach(Array(item.s.enumerated()), id: \.offset) { _, char in
                    Text(String(char))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .frame(width: 30, height: 32)
                        .background(Color.cyan.opacity(0.12))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 0.8)
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(10)
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
            Text("Linked List Node Pointers")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
            
            if nodes.isEmpty {
                Text("nil (Empty List)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(8)
            } else {
                HStack(spacing: 4) {
                    ForEach(0..<nodes.count, id: \.self) { i in
                        HStack(spacing: 4) {
                            Text("\(nodes[i])")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.purple.opacity(0.25))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.purple, lineWidth: 1)
                                )
                            if i < nodes.count - 1 {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.purple.opacity(0.7))
                            }
                        }
                    }
                    Text("-> nil")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
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
                Text("Unbounded Knapsack Rod Visualizer")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
                Text("Max Revenue: $\(item.expected)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(4)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Price Array: \(item.prices.description)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.cyan)
                
                Text("Rod Length (N): \(item.length)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
        }
    }
}


