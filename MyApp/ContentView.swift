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
        horizontalSizeClass == .compact
    }
    
    public init() {}
    
    public var body: some View {
        Group {
            if isCompact {
                // ── iOS Compact Mobile Layout ────────────────────────
                VStack(spacing: 0) {
                    topHeader
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    mobileSegmentedTabBar
                    
                    Divider().background(Color.white.opacity(0.08))
                    
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
                    .background(Color(red: 0.08, green: 0.09, blue: 0.12))
                }
            } else {
                // ── macOS & iPad Regular Desktop Layout ──────────────
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
                        topHeader
                        
                        Divider()
                            .background(Color.white.opacity(0.08))
                        
                        dsaWorkspace
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        #if os(macOS)
        .frame(minWidth: 960, minHeight: 640)
        #endif
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
    
    // MARK: - Top Header Bar
    private var topHeader: some View {
        HStack(spacing: 8) {
            // Mobile Sidebar Toggle
            if isCompact {
                Button(action: { isSidebarPresented = true }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
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
                        .lineLimit(1)
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
                HStack(spacing: 5) {
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
                .padding(.horizontal, 10)
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
            }
            .buttonStyle(PlainButtonStyle())

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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(red: 0.07, green: 0.08, blue: 0.10))
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
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(mobileTab == tab ? .white : Color(white: 0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Group {
                            if mobileTab == tab {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(LinearGradient(colors: [Color.orange.opacity(0.8), Color.red.opacity(0.7)],
                                                         startPoint: .leading, endPoint: .trailing))
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
        .background(Color(red: 0.10, green: 0.11, blue: 0.14))
    }

    // MARK: - Mobile Workspace (iOS)
    private var mobileWorkspace: some View {
        Group {
            if openBookMode {
                VStack(spacing: 0) {
                    openBookSolutionPane
                        .frame(maxHeight: .infinity)
                    Divider().background(Color.orange.opacity(0.3))
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
        .background(Color(red: 0.11, green: 0.12, blue: 0.15))
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
                                    maxLeft: geo.size.width - 320)

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
                        if isCompact { mobileTab = .solution }
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
                            if isCompact { mobileTab = .testSuite }
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
struct SplitDragHandle: View {
    @Binding var leftPaneWidth: CGFloat
    let minLeft: CGFloat
    let maxLeft: CGFloat

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
                        ? Color.orange.opacity(0.85)
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
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    }
                    .foregroundColor(isSelected ? .white : Color(white: 0.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Group {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(LinearGradient(
                                        colors: [Color.orange.opacity(0.8), Color.red.opacity(0.7)],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .shadow(color: Color.orange.opacity(0.3), radius: 4, x: 0, y: 2)
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
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.75)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { isCopied = false }
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: .medium))
                Text(isCopied ? "Copied!" : "Copy")
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
