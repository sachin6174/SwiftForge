import SwiftUI

public struct DSATestCasesView: View {
    @ObservedObject var viewModel: DSAPracticeViewModel
    @State private var showFailedOnly = false

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
            } else if (viewModel.currentQuestion?.testHarness ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // No automated harness at all (every current Machine Round
                // question is design/reference-only, graded by reading the
                // solution) — the generic "Run suite" placeholder below
                // promised structured pass/fail results that would never
                // appear, since running just executes the solution's own
                // demo prints with no CASE/PASS markers for this view to parse.
                VStack(spacing: 16) {
                    Image(systemName: "text.book.closed.fill")
                        .resizable()
                        .frame(width: 40, height: 44)
                        .foregroundStyle(LinearGradient(colors: [.mint, .teal], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Color.mint.opacity(0.4), radius: 6)
                    Text("Reference-Graded Question")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("This challenge has no automated test suite — it's graded by reading the Solution tab against the requirements in the Description tab, not by running it. 'Run Suite' still executes any safely-runnable demo snippet; check the Console for its output.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
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
                let failedCount = viewModel.testcaseResults.filter { !$0.isPass }.count
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
                } else if viewModel.testcaseResults.count > 8 {
                    // Above ~8 cases, scrolling a flat horizontal list to find
                    // the handful that failed becomes real friction (some
                    // questions now carry 50 cases) — a quick failed/all
                    // toggle plus a count badge fixes that without touching
                    // the underlying picker UI.
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                        Text("\(failedCount) of \(viewModel.testcaseResults.count) cases failed")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.red)
                        Spacer()
                        Button(action: { withAnimation(.smooth) { showFailedOnly.toggle() } }) {
                            Text(showFailedOnly ? "Show All" : "Show Failed Only")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(6)
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.95))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .overlay(Rectangle().fill(Color.red.opacity(0.25)).frame(height: 0.75), alignment: .bottom)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Testcase buttons selector
                let visibleResults = showFailedOnly ? viewModel.testcaseResults.filter { !$0.isPass } : viewModel.testcaseResults
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(visibleResults) { result in
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
                                .id(result.index)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, allPassed ? 10 : 0)
                    }
                    .onAppear {
                        scrollProxy.scrollTo(viewModel.selectedTestCaseIndex, anchor: .center)
                    }
                    .onChange(of: viewModel.selectedTestCaseIndex) { newIndex in
                        withAnimation { scrollProxy.scrollTo(newIndex, anchor: .center) }
                    }
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
}
