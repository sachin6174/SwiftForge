import SwiftUI
import JavaScriptCore
import Combine
import AppIntents
#if os(macOS)
import AppKit
#endif

@available(macOS 13.0, iOS 16.0, *)
struct CodeForgeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        return []
    }
}

@main struct CodeForgeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

public struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var dsaViewModel = DSAPracticeViewModel()
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isSidebarPresented: Bool = false
    
    public enum WorkspaceFocusMode {
        case split
        case infoFocused
        case editorFocused
    }
    
    public enum MobileWorkspaceTab: String, CaseIterable {
        case description = "Description"
        case editor = "Code"
        case solution = "Solution"
        case testSuite = "Tests"
        
        var icon: String {
            switch self {
            case .description: return "doc.text.fill"
            case .editor: return "chevron.left.forwardslash.chevron.right"
            case .solution: return "lightbulb.fill"
            case .testSuite: return "checkmark.seal.fill"
            }
        }
    }
    
    @State private var focusMode: WorkspaceFocusMode = .split
    @State private var dsaPaneTab: DSAPaneTab = .description
    @State private var mobileTab: MobileWorkspaceTab = .editor
    @State private var leftPaneWidth: CGFloat = 380
    @State private var sidebarWidth: CGFloat = 210
    /// Open Book Mode: solution on left, editor on right — simultaneously
    @State private var openBookMode: Bool = false
    @State private var celebrationID: UUID? = nil

    enum DSAPaneTab {
        case description
        case solution
        case testSuite
    }
    
    private var isCompact: Bool {
        #if os(iOS)
        return true
        #else
        return horizontalSizeClass == .compact
        #endif
    }
    
    // Sourced from the single TabAccents palette in DesignSystem.swift —
    // previously three independent switch statements here (plus matching
    // ones in SidebarView, DSASolutionView, and UIUtils) that had already
    // drifted out of sync for Swift Practice's blue.
    private var activeAccentColor: Color {
        appState.activeTab.accent.primary
    }

    private var activeAccentGradient: LinearGradient {
        appState.activeTab.accent.gradient
    }

    private var headerIconName: String {
        appState.activeTab.accent.icon
    }

    /// MCQ, Q&A, and Projects are all pure reading formats with no code
    /// editor, solution pane, or test runner behind them — everything gated
    /// on `.mcq` alone before Q&A/Projects existed (Open Book toggle,
    /// breadcrumb, dsaViewModel loading) applies identically to both.
    private var hasNoCodeWorkspace: Bool {
        appState.activeTab == .mcq || appState.activeTab == .qa || appState.activeTab == .projects
    }

    @ViewBuilder
    private var readingTabView: some View {
        switch appState.activeTab {
        case .qa: QAPracticeView(appState: appState)
        case .projects: ProjectsPracticeView(appState: appState)
        default: MCQPracticeView(appState: appState)
        }
    }

    public init() {}
    
    public var body: some View {
        Group {
            if isCompact {
                // ── iOS Compact Mobile Layout ────────────────────────
                VStack(spacing: 0) {
                    topHeader

                    Divider().background(Color.white.opacity(0.06))

                    if hasNoCodeWorkspace {
                        readingTabView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        mobileSegmentedTabBar

                        Divider().background(Color.white.opacity(0.06))

                        mobileWorkspace
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .sheet(isPresented: $isSidebarPresented) {
                    SidebarView(
                        appState: appState,
                        onDSASelect: { question in
                            dsaViewModel.loadQuestion(question, draft: appState.userActivity.draftCodes[question.id])
                            isSidebarPresented = false
                        }
                    )
                    .background(Surface.canvas)
                }
            } else {
                // ── macOS & iPad Regular Desktop Layout ──────────────
                HStack(spacing: 0) {
                    SidebarView(
                        appState: appState,
                        onDSASelect: { question in
                            dsaViewModel.loadQuestion(question, draft: appState.userActivity.draftCodes[question.id])
                            withAnimation(.easeInOut(duration: 0.2)) {
                                dsaPaneTab = .description
                            }
                        }
                    )
                    .frame(width: sidebarWidth)

                    SplitDragHandle(leftPaneWidth: $sidebarWidth,
                                    minLeft: 160,
                                    maxLeft: 400,
                                    activeTab: appState.activeTab,
                                    collapsible: true)

                    VStack(spacing: 0) {
                        topHeader

                        Divider()
                            .background(Color.white.opacity(0.06))

                        if hasNoCodeWorkspace {
                            readingTabView
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            dsaWorkspace
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay {
            if let id = celebrationID {
                SolvedCelebrationView(accentColor: activeAccentColor)
                    .id(id)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        #if os(macOS)
        .frame(minWidth: 980, minHeight: 660)
        #endif
        .onAppear {
            setupCallbacks()
            loadInitialQuestions()
            forceMacWindowRedrawAfterLayoutSettles()
        }
        .onChange(of: appState.activeTab) { _ in
            loadInitialQuestions()
        }
        .onChange(of: dsaViewModel.currentQuestion?.id) { _ in
            // Same partial-redraw glitch as the onAppear safety net below, but
            // also reproducible when switching questions/tabs post-launch: the
            // leftPane's tab picker row can render as blank background for one
            // frame (leaving a gap above the Description/Solution/Test Suite
            // bar) until something forces a full repaint.
            forceMacWindowRedrawAfterLayoutSettles()
        }
        .onChange(of: dsaViewModel.code) { newCode in
            if let q = dsaViewModel.currentQuestion {
                let currentDraft = appState.userActivity.draftCodes[q.id]
                // Skip creating a brand-new "draft" that's just the untouched
                // template — loadQuestion() sets `code` to the template on
                // first load, which would otherwise fire this onChange and
                // store a no-op draft for every question the user has ever
                // merely opened, not actually edited. Still persist the
                // template if an existing (different) draft is deliberately
                // reverted back to it.
                let isUntouchedFirstLoad = currentDraft == nil && newCode == q.templateCode
                if currentDraft != newCode && !isUntouchedFirstLoad {
                    appState.updateDraft(questionId: q.id, code: newCode)
                }
            }
        }
    }

    #if os(macOS)
    // Safety net: force a full window redraw shortly after a layout change.
    // The embedded AppKit code editor can leave part of the SwiftUI view tree
    // partially undrawn (see MacCodeEditor.makeNSView) — most visibly as a
    // blank gap where the Description/Solution/Test Suite tab bar should sit,
    // immediately below the top header, right after switching questions or
    // tabs. This guarantees a complete repaint even if that race is hit.
    private func forceMacWindowRedrawAfterLayoutSettles() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let window = NSApp.keyWindow ?? NSApp.windows.first {
                window.contentView?.needsLayout = true
                window.contentView?.needsDisplay = true
                window.displayIfNeeded()
            }
        }
    }
    #else
    private func forceMacWindowRedrawAfterLayoutSettles() {}
    #endif

    // MARK: - Top Header Bar
    private var topHeader: some View {
        HStack(spacing: 8) {
            // Mobile Sidebar Toggle
            if isCompact {
                Button(action: { isSidebarPresented = true }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(activeAccentColor)
                        #if os(iOS)
                        .padding(16)
                        #else
                        .padding(8)
                        #endif
                        .background(activeAccentColor.opacity(0.12))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(activeAccentColor.opacity(0.3), lineWidth: 0.75)
                        )
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Show question list")
            }
            
            // Header title / breadcrumb
            HStack(spacing: 6) {
                Image(systemName: headerIconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(activeAccentGradient)

                Text(appState.activeTab.rawValue)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if !hasNoCodeWorkspace, let question = dsaViewModel.currentQuestion {
                    Text("/")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.3))
                    
                    Button(action: { isSidebarPresented = true }) {
                        HStack(spacing: 4) {
                            Text(question.title)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(activeAccentColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(activeAccentColor.opacity(0.12))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(activeAccentColor.opacity(0.3), lineWidth: 0.75)
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }

            Spacer()

            // ── Open Book Mode Toggle Button ──────────────────
            // Meaningless on the MCQ/Q&A tabs (no solution/editor panes
            // exist there to split) — hidden rather than left as a dead
            // control.
            if !hasNoCodeWorkspace {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        openBookMode.toggle()
                        if openBookMode { focusMode = .split }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: openBookMode ? "book.fill" : "book")
                            .font(.system(size: 11, weight: .bold))
                        Text(openBookMode ? "Close Book" : "Open Book")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(
                        openBookMode
                            ? LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Group {
                            if openBookMode {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.blue.opacity(0.4), lineWidth: 0.75)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 0.75)
                                    )
                            }
                        }
                    )
                }
                .buttonStyle(PressableButtonStyle())
                .keyboardShortcut("b", modifiers: [.command])
            }

            // ── Stats Badges ──────────────────────────────────
            if !isCompact {
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                            )
                            .font(.system(size: 11))
                        Text("\(appState.userActivity.streak) day streak")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5.5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(
                                colors: [Color.orange.opacity(0.15), Color.red.opacity(0.08)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange.opacity(0.25), lineWidth: 0.75)
                            )
                    )
                    .pulseOnChange(appState.userActivity.streak)

                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 11))
                        if appState.activeTab == .mcq {
                            Text("\(appState.mcqCorrectCount)/\(appState.mcqQuestions.count) correct")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        } else if appState.activeTab == .qa {
                            Text("\(appState.qaViewedCount)/\(appState.qaItems.count) read")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        } else if appState.activeTab == .projects {
                            Text("\(appState.projectViewedCount)/\(appState.projectItems.count) reviewed")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        } else {
                            let solved = appState.userActivity.solvedQuestionIds.count
                            Text("\(solved)/\(appState.questions.count) solved")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5.5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green.opacity(0.25), lineWidth: 0.75)
                            )
                    )
                    .pulseOnChange(
                        appState.activeTab == .mcq ? appState.mcqCorrectCount :
                        appState.activeTab == .qa ? appState.qaViewedCount :
                        appState.activeTab == .projects ? appState.projectViewedCount :
                        appState.userActivity.solvedQuestionIds.count
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Surface.raised)
        .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 4)
    }

    // MARK: - Mobile Segmented Tab Bar (iOS)
    private var mobileSegmentedTabBar: some View {
        HStack(spacing: 4) {
            ForEach(MobileWorkspaceTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        mobileTab = tab
                        if tab == .solution { dsaPaneTab = .solution }
                        if tab == .description { dsaPaneTab = .description }
                        if tab == .testSuite { dsaPaneTab = .testSuite }
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .bold))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(mobileTab == tab ? .white : Color.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Group {
                            if mobileTab == tab {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(activeAccentGradient)
                                    .shadow(color: activeAccentColor.opacity(0.3), radius: 4)
                            } else {
                                Color.clear
                            }
                        }
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(4)
        .background(Surface.raised)
    }

    // MARK: - Mobile Workspace (iOS)
    private var mobileWorkspace: some View {
        Group {
            if openBookMode {
                VStack(spacing: 0) {
                    openBookSolutionPane
                        .frame(maxHeight: .infinity)
                    Divider().background(activeAccentColor.opacity(0.3))
                    openBookEditorPane
                        .frame(maxHeight: .infinity)
                }
            } else {
                switch mobileTab {
                case .description:
                    DSADescriptionView(question: dsaViewModel.currentQuestion)
                case .solution:
                    openBookSolutionPane
                case .editor:
                    rightPane
                case .testSuite:
                    VStack(spacing: 0) {
                        DSATestCasesView(viewModel: dsaViewModel)
                            .padding(12)
                        Divider().background(Color.white.opacity(0.08))
                        ConsoleView(output: dsaViewModel.consoleOutput, compilerError: dsaViewModel.compilerError, isRunning: dsaViewModel.isRunning)
                            .frame(height: 200)
                    }
                }
            }
        }
        .forgeCanvas(Surface.base, glow: activeAccentColor, glowIntensity: 0.05)
    }

    // MARK: - Desktop / iPad DSA Workspace
    private var dsaWorkspace: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                if openBookMode {
                    openBookSolutionPane
                        .frame(width: leftPaneWidth)

                    SplitDragHandle(leftPaneWidth: $leftPaneWidth,
                                    minLeft: 280,
                                    maxLeft: geo.size.width - 320,
                                    activeTab: appState.activeTab)

                    openBookEditorPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if focusMode != .editorFocused {
                        leftPane
                            .frame(
                                width: focusMode == .infoFocused ? nil : leftPaneWidth,
                                alignment: .leading
                            )
                            .frame(
                                maxWidth: focusMode == .infoFocused ? .infinity : leftPaneWidth,
                                maxHeight: .infinity
                            )
                    }

                    if focusMode == .split {
                        SplitDragHandle(leftPaneWidth: $leftPaneWidth,
                                        minLeft: 260,
                                        maxLeft: geo.size.width - 320,
                                        activeTab: appState.activeTab)
                    }

                    if focusMode != .infoFocused {
                        rightPane
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .forgeCanvas(Surface.base, glow: activeAccentColor, glowIntensity: 0.05)
        }
    }

    // MARK: - Open Book Solution Pane
    private var openBookSolutionPane: some View {
        DSASolutionView(
            question: dsaViewModel.currentQuestion,
            isFocused: false,
            onToggleFocus: nil,
            onInsertToEditor: { code in
                dsaViewModel.insertCodeToEditor(code)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Surface.base)
    }

    // MARK: - Open Book Editor Pane
    private var openBookEditorPane: some View {
        CodeEditorView(
            code: $dsaViewModel.code,
            fileName: "Solution.swift",
            isFocused: false,
            onToggleFocus: {},
            accent: activeAccentColor
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Surface.canvas)
    }

    // MARK: - Left Pane
    private var leftPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                CustomSegmentedPicker(
                    selection: $dsaPaneTab,
                    items: [DSAPaneTab.description, DSAPaneTab.solution, DSAPaneTab.testSuite],
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
                    },
                    activeTab: appState.activeTab
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
                    .foregroundColor(focusMode == .infoFocused ? activeAccentColor : Color.white.opacity(0.4))
                    .padding(6)
                    .background(focusMode == .infoFocused
                                ? activeAccentColor.opacity(0.15)
                                : Color.white.opacity(0.04))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(focusMode == .infoFocused ? activeAccentColor.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 0.75)
                    )
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(focusMode == .infoFocused ? "Exit full screen" : "Full screen")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().background(Color.white.opacity(0.06))

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
                        onInsertToEditor: { code in
                            dsaViewModel.insertCodeToEditor(code)
                        }
                    )
                case .testSuite:
                    DSATestCasesView(viewModel: dsaViewModel)
                        .padding(12)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .background(Surface.base)
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
                },
                accent: activeAccentColor
            )
            .frame(maxHeight: .infinity)

            Divider().background(Color.white.opacity(0.06))

            // Command Toolbar
            HStack(spacing: 10) {
                Button(action: { dsaViewModel.resetCode() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .bold))
                        Text("Reset")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(Color.white.opacity(0.55))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.75)
                    )
                }
                .buttonStyle(PressableButtonStyle())

                Button(action: {
                    withAnimation {
                        dsaPaneTab = .solution
                        if focusMode == .editorFocused { focusMode = .split }
                        if isCompact { mobileTab = .solution }
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Solution")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(activeAccentGradient)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(activeAccentColor.opacity(0.12))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(activeAccentColor.opacity(0.3), lineWidth: 0.75)
                    )
                }
                .buttonStyle(PressableButtonStyle())

                CopyCodeButton(code: dsaViewModel.code)

                Spacer()

                DSARunButton(isRunning: dsaViewModel.isRunning) {
                    appState.incrementRunCount()
                    Task {
                        withAnimation {
                            if focusMode == .editorFocused { focusMode = .split }
                            dsaPaneTab = .testSuite
                            if isCompact { mobileTab = .testSuite }
                        }
                        await dsaViewModel.runCode()
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Surface.raised)

            Divider().background(Color.white.opacity(0.06))

            ConsoleView(
                output: dsaViewModel.consoleOutput,
                compilerError: dsaViewModel.compilerError,
                isRunning: dsaViewModel.isRunning
            )
            .frame(height: 180)
        }
    }
    
    private func setupCallbacks() {
        dsaViewModel.onSuccess = {
            if let q = dsaViewModel.currentQuestion {
                let alreadySolved = appState.userActivity.solvedQuestionIds.contains(q.id)
                appState.markQuestionSolved(questionId: q.id)
                if !alreadySolved {
                    triggerCelebration()
                }
            }
        }
    }

    /// Shows the solved celebration for ~1.7s. Gated to first-time solves in
    /// `setupCallbacks` so re-running an already-solved suite doesn't replay
    /// it — repeating the same reward on every run would cheapen it.
    private func triggerCelebration() {
        let id = UUID()
        celebrationID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            if celebrationID == id { celebrationID = nil }
        }
    }
    
    private func loadInitialQuestions() {
        // MCQ/Q&A tabs have no code editor/runner — MCQPracticeView and
        // QAPracticeView read their own selected item directly, nothing for
        // dsaViewModel to load.
        guard !hasNoCodeWorkspace else { return }
        let initialQuestion: Question?
        switch appState.activeTab {
        case .swiftPractice: initialQuestion = appState.selectedSwiftQuestion
        case .machineRound: initialQuestion = appState.selectedMachineRoundQuestion
        case .dsa, .mcq, .qa, .projects: initialQuestion = appState.selectedDSAQuestion
        }
        if let question = initialQuestion ?? appState.selectedDSAQuestion {
            dsaViewModel.loadQuestion(question, draft: appState.userActivity.draftCodes[question.id])
        }
    }
}

// MARK: - Draggable Split Handle
/// Shared per-tab accent color for chrome that lives outside ContentView's
/// own `activeAccentColor` (the drag handle and pane picker below are
/// separate top-level structs, not methods on ContentView) — previously a
/// bare `activeTab == .swiftPractice ? .blue : .orange` ternary, which
/// defaulted BOTH `.mcq` and `.machineRound` to the DSA orange with no
/// dedicated case for either.
func practiceTabAccentColor(_ tab: PracticeTab) -> Color {
    tab.accent.primary
}

struct SplitDragHandle: View {
    @Binding var leftPaneWidth: CGFloat
    let minLeft: CGFloat
    let maxLeft: CGFloat
    let activeTab: PracticeTab
    /// When true, dragging past a dead zone near `minLeft` (half of it)
    /// snaps the pane fully shut (width 0) instead of stopping at `minLeft`
    /// — dragging back out past that same dead zone pops it back open to
    /// `minLeft`. Off by default so the other two panes this same handle
    /// already drives (the Description/Editor split, and Open Book mode)
    /// keep their existing "never fully hide" behavior; only the sidebar
    /// opts in.
    var collapsible: Bool = false

    @State private var isHovering = false
    @State private var isDragging = false
    // Captured once per gesture (at its first .onChanged) rather than
    // re-derived from `leftPaneWidth` on every callback — `translation` is
    // ALWAYS cumulative from the gesture's start, so recomputing
    // `leftPaneWidth + translation` against a `leftPaneWidth` that this same
    // closure already overwrote on the previous callback double-counts
    // every earlier increment, making the pane grow/shrink faster than the
    // actual pointer movement (compounding with every callback in one
    // continuous drag). Anchoring to a single start-of-gesture snapshot
    // makes the resulting width a pure function of total pointer movement,
    // exactly matching the pointer.
    @State private var dragStartWidth: CGFloat?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 12)
                .contentShape(Rectangle())

            Rectangle()
                .fill(
                    isDragging
                        ? practiceTabAccentColor(activeTab)
                        : isHovering
                            ? Color.white.opacity(0.4)
                            : Color.white.opacity(0.12)
                )
                .frame(width: isDragging ? 2 : 1)
                .animation(.easeInOut(duration: 0.15), value: isDragging)
                .animation(.easeInOut(duration: 0.12), value: isHovering)

            VStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { _ in
                    Circle()
                        .fill(
                            isDragging
                                ? practiceTabAccentColor(activeTab)
                                : (isHovering ? Color.white.opacity(0.7) : Color.white.opacity(0.25))
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
            #if os(macOS)
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else if !isDragging {
                NSCursor.pop()
            }
            #endif
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        dragStartWidth = leftPaneWidth
                        #if os(macOS)
                        NSCursor.resizeLeftRight.push()
                        #endif
                    }
                    let proposed = (dragStartWidth ?? leftPaneWidth) + value.translation.width
                    if collapsible {
                        // Hysteresis, not a single shared threshold: collapsing
                        // needs `proposed` below minLeft/2, but REOPENING needs
                        // it past the full minLeft — a wider bar than the one
                        // that closed it. With one shared threshold at minLeft/2,
                        // the ordinary jitter in any real mouse/trackpad drag
                        // (the pointer's instantaneous position isn't monotonic
                        // even while the user's overall intent is) flips
                        // `proposed` back and forth across that single line on
                        // consecutive .onChanged callbacks, snapping the pane
                        // between 0 and minLeft on every micro-jitter — visible
                        // as exactly the rapid-fire flicker reported here. Which
                        // threshold applies is read fresh from the CURRENT
                        // leftPaneWidth each callback (not cached), so the gap
                        // between minLeft/2 and minLeft is a dead zone once
                        // collapsed: nothing changes until the pointer clears it
                        // decisively in either direction.
                        if leftPaneWidth <= 0 {
                            if proposed > minLeft {
                                leftPaneWidth = min(proposed, maxLeft)
                            }
                        } else if proposed < minLeft / 2 {
                            leftPaneWidth = 0
                        } else {
                            leftPaneWidth = min(max(proposed, minLeft), maxLeft)
                        }
                    } else {
                        leftPaneWidth = min(max(proposed, minLeft), maxLeft)
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    dragStartWidth = nil
                    #if os(macOS)
                    NSCursor.pop()
                    #endif
                }
        )
        .accessibilityLabel("Resize panes")
        .accessibilityAdjustableAction { direction in
            let step: CGFloat = 24
            switch direction {
            case .increment:
                leftPaneWidth = min(leftPaneWidth + step, maxLeft)
            case .decrement:
                leftPaneWidth = max(leftPaneWidth - step, minLeft)
            @unknown default:
                break
            }
        }
    }
}

struct CustomSegmentedPicker<T: Hashable>: View {
    @Binding var selection: T
    let items: [T]
    let titleFor: (T) -> String
    let iconFor: (T) -> String
    let activeTab: PracticeTab

    private var pickerGradient: LinearGradient {
        LinearGradient(
            colors: [activeTab.accent.primary.opacity(0.85), activeTab.accent.secondary.opacity(0.75)],
            startPoint: .leading, endPoint: .trailing
        )
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                let isSelected = selection == item
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = item
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: iconFor(item))
                            .font(.system(size: 11))
                        Text(titleFor(item))
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                    }
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.45))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Group {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(pickerGradient)
                                    .shadow(color: practiceTabAccentColor(activeTab).opacity(0.3), radius: 4, x: 0, y: 1)
                            } else {
                                Color.clear
                            }
                        }
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.75)
                )
        )
    }
}

// MARK: - Copy Code Button Component
struct CopyCodeButton: View {
    let code: String
    @State private var isCopied = false

    var body: some View {
        Button(action: {
            #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
            #elseif os(iOS)
            UIPasteboard.general.string = code
            #endif
            withAnimation { isCopied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { isCopied = false }
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: .bold))
                Text(isCopied ? "Copied!" : "Copy")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(isCopied ? .green : Color.white.opacity(0.55))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isCopied ? Color.green.opacity(0.12) : Color.white.opacity(0.04))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isCopied ? Color.green.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.75)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}
