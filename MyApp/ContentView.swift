import SwiftUI
import JavaScriptCore
import Combine
import AppIntents

@available(macOS 13.0, iOS 16.0, *)
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
    
    public enum WorkspaceFocusMode {
        case split
        case infoFocused
        case editorFocused
    }
    
    @State private var focusMode: WorkspaceFocusMode = .split
    @State private var dsaPaneTab: DSAPaneTab = .description
    @State private var leftPaneWidth: CGFloat = 380
    /// Open Book Mode: solution on left, editor on right — simultaneously
    @State private var openBookMode: Bool = false

    enum DSAPaneTab {
        case description
        case solution
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
        .onChange(of: dsaViewModel.code) { newCode in
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

            // ── Open Book Mode Toggle Button ──────────────────
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    openBookMode.toggle()
                    // Exit any focus mode so both panes are visible
                    if openBookMode { focusMode = .split }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: openBookMode ? "book.fill" : "book")
                        .font(.system(size: 11, weight: .semibold))
                    Text(openBookMode ? "Close Book" : "Open Book")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(
                    openBookMode
                        ? LinearGradient(colors: [Color(hue: 0.55, saturation: 0.85, brightness: 1.0),
                                                  Color(hue: 0.6,  saturation: 0.9,  brightness: 0.9)],
                                         startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color(white: 0.55), Color(white: 0.45)],
                                         startPoint: .leading, endPoint: .trailing)
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Group {
                        if openBookMode {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color(hue: 0.57, saturation: 0.6, brightness: 0.25))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color(hue: 0.55, saturation: 0.85, brightness: 0.9).opacity(0.7),
                                                         Color(hue: 0.6,  saturation: 0.9,  brightness: 0.8).opacity(0.5)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 0.75)
                                )
                        }
                    }
                )
                .shadow(
                    color: openBookMode ? Color(hue: 0.57, saturation: 0.8, brightness: 0.8).opacity(0.35) : .clear,
                    radius: 8, x: 0, y: 2
                )
            }
            .buttonStyle(PlainButtonStyle())
            .animation(.easeInOut(duration: 0.2), value: openBookMode)

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
        GeometryReader { geo in
            HStack(spacing: 0) {
                if openBookMode {
                    // ══ OPEN BOOK MODE ════════════════════════════════════
                    // Left = Official Solution (read-only)
                    openBookSolutionPane
                        .frame(width: leftPaneWidth)

                    SplitDragHandle(leftPaneWidth: $leftPaneWidth,
                                    minLeft: 280,
                                    maxLeft: geo.size.width - 320)

                    // Right = User's Code Editor (pure, no toolbar/console)
                    openBookEditorPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else {
                    // ══ NORMAL MODE ═══════════════════════════════════════
                    if focusMode != .editorFocused {
                        leftPane
                            .frame(
                                width: focusMode == .infoFocused ? nil : leftPaneWidth,
                                alignment: .leading
                            )
                            .frame(
                                maxWidth: focusMode == .infoFocused ? .infinity : leftPaneWidth
                            )
                    }

                    if focusMode == .split {
                        SplitDragHandle(leftPaneWidth: $leftPaneWidth,
                                        minLeft: 260,
                                        maxLeft: geo.size.width - 320)
                    }

                    if focusMode != .infoFocused {
                        rightPane
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .background(Color(red: 0.11, green: 0.12, blue: 0.15))
        }
    }

    // MARK: - Open Book Solution Pane
    /// Left pane in Open Book Mode: ONLY the solution, full height, nothing else.
    private var openBookSolutionPane: some View {
        DSASolutionView(
            question: dsaViewModel.currentQuestion,
            isFocused: false,
            onToggleFocus: nil,
            onInsertToEditor: {
                dsaViewModel.insertSolutionToEditor()
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.09, green: 0.11, blue: 0.16))
    }

    // MARK: - Open Book Editor Pane
    /// Right pane in Open Book Mode: ONLY the code editor, full height, nothing else.
    private var openBookEditorPane: some View {
        CodeEditorView(
            code: $dsaViewModel.code,
            fileName: "Solution.swift",
            isFocused: false,
            onToggleFocus: {}
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.09, green: 0.10, blue: 0.13))
    }

    // MARK: - Left Pane
    private var leftPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                CustomSegmentedPicker(
                    selection: $dsaPaneTab,
                    items: [.description, .solution, .testSuite],
                    titleFor: { tab in
                        switch tab {
                        case .description: return "Description"
                        case .solution: return "Solution"
                        case .testSuite: return "Test Suite"
                        }
                    },
                    iconFor: { tab in
                        switch tab {
                        case .description: return "doc.text.fill"
                        case .solution: return "lightbulb.fill"
                        case .testSuite: return "checkmark.seal.fill"
                        }
                    }
                )

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        focusMode = (focusMode == .infoFocused) ? .split : .infoFocused
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: focusMode == .infoFocused
                              ? "arrow.down.right.and.arrow.up.left"
                              : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(focusMode == .infoFocused ? .orange : Color(white: 0.5))
                    .padding(6)
                    .background(focusMode == .infoFocused
                                ? Color.orange.opacity(0.15)
                                : Color.white.opacity(0.06))
                    .cornerRadius(5)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            Divider().background(Color.white.opacity(0.08))

            Group {
                switch dsaPaneTab {
                case .description:
                    DSADescriptionView(question: dsaViewModel.currentQuestion)
                case .solution:
                    DSASolutionView(
                        question: dsaViewModel.currentQuestion,
                        isFocused: focusMode == .infoFocused,
                        onToggleFocus: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                focusMode = (focusMode == .infoFocused) ? .split : .infoFocused
                            }
                        },
                        onInsertToEditor: {
                            dsaViewModel.insertSolutionToEditor()
                        }
                    )
                case .testSuite:
                    DSATestCasesView(viewModel: dsaViewModel)
                        .padding(12)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .background(Color(red: 0.12, green: 0.14, blue: 0.18))
    }

    // MARK: - Right Pane
    private var rightPane: some View {
        VStack(spacing: 0) {
            CodeEditorView(
                code: $dsaViewModel.code,
                fileName: "Solution.swift",
                isFocused: focusMode == .editorFocused && !openBookMode,
                onToggleFocus: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if !openBookMode {
                            focusMode = (focusMode == .editorFocused) ? .split : .editorFocused
                        }
                    }
                }
            )
            .frame(maxHeight: .infinity)

            Divider().background(Color.white.opacity(0.08))

            // Command Toolbar
            HStack(spacing: 10) {
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

                Button(action: {
                    withAnimation {
                        dsaPaneTab = .solution
                        if focusMode == .editorFocused { focusMode = .split }
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10, weight: .medium))
                        Text("Solution")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .red],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                LinearGradient(colors: [Color.orange.opacity(0.5), Color.red.opacity(0.4)],
                                               startPoint: .leading, endPoint: .trailing),
                                lineWidth: 0.75
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())

                CopyCodeButton(code: dsaViewModel.code)

                Spacer()

                DSARunButton(isRunning: dsaViewModel.isRunning) {
                    appState.incrementRunCount()
                    Task {
                        withAnimation {
                            if focusMode == .editorFocused { focusMode = .split }
                            dsaPaneTab = .testSuite
                        }
                        await dsaViewModel.runCode()
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(red: 0.08, green: 0.09, blue: 0.11))

            Divider().background(Color.white.opacity(0.08))

            ConsoleView(
                output: dsaViewModel.consoleOutput,
                compilerError: dsaViewModel.compilerError
            )
            .frame(height: 180)
        }
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

// MARK: - Draggable Split Handle
/// A slim, interactive divider that lets the user drag left/right
/// to resize the left info pane vs the right code-editor pane.
struct SplitDragHandle: View {
    @Binding var leftPaneWidth: CGFloat
    let minLeft: CGFloat
    let maxLeft: CGFloat

    @State private var isHovering = false
    @State private var isDragging = false

    var body: some View {
        ZStack {
            // Invisible wide hit area for easy grab
            Rectangle()
                .fill(Color.clear)
                .frame(width: 12)
                .contentShape(Rectangle())

            // Visible thin line
            Rectangle()
                .fill(
                    isDragging
                        ? Color.orange.opacity(0.85)
                        : isHovering
                            ? Color.white.opacity(0.4)
                            : Color.white.opacity(0.12)
                )
                .frame(width: isDragging ? 2 : 1)
                .animation(.easeInOut(duration: 0.15), value: isDragging)
                .animation(.easeInOut(duration: 0.12), value: isHovering)

            // Grip dots
            VStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { _ in
                    Circle()
                        .fill(
                            isDragging ? Color.orange : (isHovering ? Color.white.opacity(0.7) : Color.white.opacity(0.25))
                        )
                        .frame(width: 3, height: 3)
                }
            }
            .opacity(isHovering || isDragging ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .frame(width: 12)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else if !isDragging {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        NSCursor.resizeLeftRight.push()
                    }
                    let proposed = leftPaneWidth + value.translation.width
                    leftPaneWidth = min(max(proposed, minLeft), maxLeft)
                }
                .onEnded { _ in
                    isDragging = false
                    NSCursor.pop()
                }
        )
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
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
                #elseif os(iOS)
                UIPasteboard.general.string = code
                #endif
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
