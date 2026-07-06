import SwiftUI
import JavaScriptCore
import Combine
import AppIntents
#if os(macOS)
import AppKit
#endif

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
    /// Open Book Mode: solution on left, editor on right — simultaneously
    @State private var openBookMode: Bool = false

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
    
    private var activeAccentColor: Color {
        appState.activeTab == .swiftPractice ? .blue : .orange
    }
    
    private var activeAccentGradient: LinearGradient {
        if appState.activeTab == .swiftPractice {
            return LinearGradient(colors: [Color(red: 0.1, green: 0.6, blue: 1.0), Color(red: 0.0, green: 0.85, blue: 0.9)], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing)
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
                    
                    mobileSegmentedTabBar
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    mobileWorkspace
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .sheet(isPresented: $isSidebarPresented) {
                    SidebarView(
                        appState: appState,
                        onDSASelect: { question in
                            dsaViewModel.loadQuestion(question, draft: appState.userActivity.draftCodes[question.id])
                            isSidebarPresented = false
                        }
                    )
                    .background(Color(red: 0.05, green: 0.06, blue: 0.09))
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
                    
                    Divider()
                        .background(Color.white.opacity(0.08))
                    
                    VStack(spacing: 0) {
                        topHeader
                        
                        Divider()
                            .background(Color.white.opacity(0.06))
                        
                        dsaWorkspace
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        #if os(macOS)
        .frame(minWidth: 980, minHeight: 660)
        #endif
        .onAppear {
            setupCallbacks()
            loadInitialQuestions()
            #if os(macOS)
            // Safety net: force a full window redraw shortly after first appearance.
            // The embedded AppKit code editor can leave the window's very first
            // SwiftUI frame partially undrawn (see MacCodeEditor.makeNSView); this
            // guarantees a complete repaint even if that race is hit some other way.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if let window = NSApp.keyWindow ?? NSApp.windows.first {
                    window.contentView?.needsLayout = true
                    window.contentView?.needsDisplay = true
                    window.displayIfNeeded()
                }
            }
            #endif
        }
        .onChange(of: appState.activeTab) { _ in
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
    
    // MARK: - Top Header Bar
    private var topHeader: some View {
        HStack(spacing: 8) {
            // Mobile Sidebar Toggle
            if isCompact {
                Button(action: { isSidebarPresented = true }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(activeAccentColor)
                        .padding(8)
                        .background(activeAccentColor.opacity(0.12))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(activeAccentColor.opacity(0.3), lineWidth: 0.75)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Header title / breadcrumb
            HStack(spacing: 6) {
                Image(systemName: appState.activeTab == .swiftPractice ? "network" : "square.grid.3x3.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(activeAccentGradient)
                
                Text(appState.activeTab.rawValue)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                if let question = dsaViewModel.currentQuestion {
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
                    .buttonStyle(PlainButtonStyle())
                }
            }

            Spacer()

            // ── Open Book Mode Toggle Button ──────────────────
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
            .buttonStyle(PlainButtonStyle())
            .keyboardShortcut("b", modifiers: [.command])

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

                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 11))
                        let solved = appState.userActivity.solvedQuestionIds.count
                        Text("\(solved)/\(appState.questions.count) solved")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
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
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.08, green: 0.09, blue: 0.12))
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
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(Color(red: 0.1, green: 0.11, blue: 0.14))
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
                        ConsoleView(output: dsaViewModel.consoleOutput, compilerError: dsaViewModel.compilerError)
                            .frame(height: 200)
                    }
                }
            }
        }
        .background(Color(red: 0.08, green: 0.09, blue: 0.12))
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
            .background(Color(red: 0.08, green: 0.09, blue: 0.12))
        }
    }

    // MARK: - Open Book Solution Pane
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
        .background(Color(red: 0.08, green: 0.09, blue: 0.12))
    }

    // MARK: - Open Book Editor Pane
    private var openBookEditorPane: some View {
        CodeEditorView(
            code: $dsaViewModel.code,
            fileName: "Solution.swift",
            isFocused: false,
            onToggleFocus: {}
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.05, green: 0.06, blue: 0.08))
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
                .buttonStyle(PlainButtonStyle())
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
        .background(Color(red: 0.08, green: 0.09, blue: 0.12))
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
                .buttonStyle(PlainButtonStyle())

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
                .buttonStyle(PlainButtonStyle())

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
            .background(Color(red: 0.1, green: 0.11, blue: 0.14))

            Divider().background(Color.white.opacity(0.06))

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
        let initialQuestion = (appState.activeTab == .swiftPractice ? appState.selectedSwiftQuestion : appState.selectedDSAQuestion) ?? appState.selectedDSAQuestion
        if let question = initialQuestion {
            dsaViewModel.loadQuestion(question, draft: appState.userActivity.draftCodes[question.id])
        }
    }
}

// MARK: - Draggable Split Handle
struct SplitDragHandle: View {
    @Binding var leftPaneWidth: CGFloat
    let minLeft: CGFloat
    let maxLeft: CGFloat
    let activeTab: PracticeTab

    @State private var isHovering = false
    @State private var isDragging = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 12)
                .contentShape(Rectangle())

            Rectangle()
                .fill(
                    isDragging
                        ? (activeTab == .swiftPractice ? Color.blue : Color.orange)
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
                                ? (activeTab == .swiftPractice ? Color.blue : Color.orange) 
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
                        #if os(macOS)
                        NSCursor.resizeLeftRight.push()
                        #endif
                    }
                    let proposed = leftPaneWidth + value.translation.width
                    leftPaneWidth = min(max(proposed, minLeft), maxLeft)
                }
                .onEnded { _ in
                    isDragging = false
                    #if os(macOS)
                    NSCursor.pop()
                    #endif
                }
        )
    }
}

struct CustomSegmentedPicker<T: Hashable>: View {
    @Binding var selection: T
    let items: [T]
    let titleFor: (T) -> String
    let iconFor: (T) -> String
    let activeTab: PracticeTab

    private var pickerGradient: LinearGradient {
        if activeTab == .swiftPractice {
            return LinearGradient(
                colors: [Color.blue.opacity(0.85), Color.cyan.opacity(0.75)],
                startPoint: .leading, endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color.orange.opacity(0.85), Color.red.opacity(0.75)],
                startPoint: .leading, endPoint: .trailing
            )
        }
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
                                    .shadow(color: (activeTab == .swiftPractice ? Color.blue : Color.orange).opacity(0.3), radius: 4, x: 0, y: 1)
                            } else {
                                Color.clear
                            }
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
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
        .buttonStyle(PlainButtonStyle())
    }
}
