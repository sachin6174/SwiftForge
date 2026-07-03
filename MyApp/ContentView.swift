import SwiftUI
import JavaScriptCore
import Combine
import AppIntents

struct SwiftForgeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        return []
    }
}

@main struct SwiftForgeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

public struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var dsaViewModel = DSAPracticeViewModel()
    
    // UI Pane state
    @State private var dsaPaneTab: DSAPaneTab = .description
    
    enum DSAPaneTab {
        case description
        case testSuite
    }
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                appState: appState,
                onDSASelect: { question in
                    dsaViewModel.loadQuestion(question, draft: appState.userActivity.draftCodes[question.id])
                    withAnimation {
                        dsaPaneTab = .description
                    }
                }
            )
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            VStack(spacing: 0) {
                // Premium Top Header Banner
                topHeader
                
                Divider()
                    .background(Color.white.opacity(0.08))
                
                // Main Content Area (DSA Workspace)
                dsaWorkspace
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 1100, minHeight: 700)
        .environmentObject(appState)
        .onAppear {
            setupCallbacks()
            loadInitialQuestions()
        }
        .onChange(of: dsaViewModel.code) { _, newCode in
            if let q = dsaViewModel.currentQuestion {
                let currentDraft = appState.userActivity.draftCodes[q.id]
                if currentDraft != newCode {
                    appState.updateDraft(questionId: q.id, code: newCode)
                }
            }
        }
    }
    
    private var topHeader: some View {
        HStack(spacing: 0) {
            // Header title / breadcrumb
            HStack(spacing: 6) {
                Image(systemName: appState.activeTab == .swiftPractice ? "network" : "square.grid.3x3.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        appState.activeTab == .swiftPractice
                            ? LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                    )
                
                Text(appState.activeTab.rawValue)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                if let question = dsaViewModel.currentQuestion {
                    Text("/")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.35))
                    Text(question.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(white: 0.65))
                }
            }

            Spacer()

            // ── Stats Badges ──────────────────────────────────
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                        )
                        .font(.system(size: 11))
                    Text("\(appState.userActivity.streak) day streak")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [Color.orange.opacity(0.18), Color.red.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 0.75)
                        )
                )

                HStack(spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 11))
                    let solved = appState.userActivity.solvedQuestionIds.count
                    Text("\(solved)/\(appState.questions.count) solved")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.green.opacity(0.28), lineWidth: 0.75)
                        )
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.10)
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [Color.orange.opacity(0.10), Color.clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(height: 1)
                }
            }
        )
    }

    private var dsaWorkspace: some View {
        HStack(spacing: 0) {
            // Left Column Pane (Questions & Description & Test Suite tabs: 380px)
            VStack(spacing: 0) {
                CustomSegmentedPicker(
                    selection: $dsaPaneTab,
                    items: [.description, .testSuite],
                    titleFor: { tab in
                        switch tab {
                        case .description: return "Description"
                        case .testSuite: return "Test Suite"
                        }
                    },
                    iconFor: { tab in
                        switch tab {
                        case .description: return "doc.text.fill"
                        case .testSuite: return "checkmark.seal.fill"
                        }
                    }
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                
                Divider()
                    .background(Color.white.opacity(0.08))
                
                Group {
                    switch dsaPaneTab {
                    case .description:
                        DSADescriptionView(question: dsaViewModel.currentQuestion)
                    case .testSuite:
                        DSATestCasesView(viewModel: dsaViewModel)
                            .padding(12)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(width: 380)
            .background(Color(red: 0.12, green: 0.14, blue: 0.18))
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Right Column Pane (Fluid Code Editor and Terminal output)
            VStack(spacing: 0) {
                CodeEditorView(code: $dsaViewModel.code, fileName: "Solution.swift")
                    .frame(maxHeight: .infinity)
                
                Divider()
                    .background(Color.white.opacity(0.08))
                
                // Command Toolbar - DSA
                HStack(spacing: 10) {
                    // Ghost reset button
                    Button(action: { dsaViewModel.resetCode() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10, weight: .medium))
                            Text("Reset")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(Color(white: 0.5))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.75)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Orange outline Load Solution
                    Button(action: { dsaViewModel.loadSolution() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 10, weight: .medium))
                            Text("Solution")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(
                            LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                        )
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    LinearGradient(colors: [Color.orange.opacity(0.5), Color.red.opacity(0.4)], startPoint: .leading, endPoint: .trailing),
                                    lineWidth: 0.75
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Copy Code Button
                    CopyCodeButton(code: dsaViewModel.code)

                    Spacer()

                    // Glowing Run Suite button
                    DSARunButton(isRunning: dsaViewModel.isRunning) {
                        appState.incrementRunCount()
                        Task {
                            withAnimation { dsaPaneTab = .testSuite }
                            await dsaViewModel.runCode()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(red: 0.08, green: 0.09, blue: 0.11))
                
                Divider()
                    .background(Color.white.opacity(0.08))
                
                ConsoleView(output: dsaViewModel.consoleOutput, compilerError: dsaViewModel.compilerError)
            }
        }
        .background(Color(red: 0.11, green: 0.12, blue: 0.15))
    }
    
    private func setupCallbacks() {
        dsaViewModel.onSuccess = {
            if let q = dsaViewModel.currentQuestion {
                appState.markQuestionSolved(questionId: q.id)
            }
        }
    }
    
    private func loadInitialQuestions() {
        if let dsaQ = appState.selectedDSAQuestion {
            dsaViewModel.loadQuestion(dsaQ, draft: appState.userActivity.draftCodes[dsaQ.id])
        }
    }
}

struct CustomSegmentedPicker<T: Hashable>: View {
    @Binding var selection: T
    let items: [T]
    let titleFor: (T) -> String
    let iconFor: (T) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                let isSelected = selection == item

                Button(action: {
                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.72)) {
                        selection = item
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: iconFor(item))
                            .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(
                                isSelected
                                    ? LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                            )
                        Text(titleFor(item))
                            .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .white : Color(white: 0.5))
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        Group {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.orange.opacity(0.22), Color.red.opacity(0.14)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.orange.opacity(0.3), lineWidth: 0.75)
                                    )
                                    .shadow(color: Color.orange.opacity(0.2), radius: 4, y: 2)
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.clear)
                            }
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color(red: 0.06, green: 0.07, blue: 0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.75)
                )
        )
    }
}
// MARK: - Premium Run Button with Glow Pulse
struct DSARunButton: View {
    let isRunning: Bool
    let action: () -> Void

    @State private var glowPulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isRunning {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.65)
                    Text("Running...")
                        .font(.system(size: 11, weight: .semibold))
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Run Suite")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [Color.orange, Color(red: 0.9, green: 0.2, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .cornerRadius(7)

                    // Outer glow pulse when idle
                    if !isRunning {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.orange.opacity(glowPulse ? 0.55 : 0.15), lineWidth: glowPulse ? 2 : 1)
                            .scaleEffect(glowPulse ? 1.04 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                                value: glowPulse
                            )
                    }
                }
            )
            .shadow(color: Color.orange.opacity(isRunning ? 0.1 : 0.3), radius: isRunning ? 2 : 6, y: 2)
            .cornerRadius(7)
        }
        .buttonStyle(PlainButtonStyle())
        .keyboardShortcut("r", modifiers: .command)
        .disabled(isRunning)
        .onAppear { glowPulse = true }
    }
}

// MARK: - Reusable Copy Code Button Component
struct CopyCodeButton: View {
    let code: String
    @State private var isCopied = false

    var body: some View {
        Button(action: {
            if !code.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
                withAnimation(.easeInOut(duration: 0.15)) {
                    isCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isCopied = false
                    }
                }
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: .medium))
                Text(isCopied ? "Copied!" : "Copy Code")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isCopied ? .green : Color(white: 0.5))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isCopied ? Color.green.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 0.75)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
