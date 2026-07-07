import SwiftUI

public struct SidebarView: View {
    @ObservedObject var appState: AppState
    let onDSASelect: (Question) -> Void

    @State private var statusPulse = false
    @State private var searchText = ""
    @State private var isHoveringHeader = false
    @State private var collapsedSections: Set<String> = []
    @FocusState private var isSearchFocused: Bool

    public init(appState: AppState, onDSASelect: @escaping (Question) -> Void) {
        self.appState = appState
        self.onDSASelect = onDSASelect
    }

    // Filtered challenges list
    private var filteredDSAQuestions: [Question] {
        if searchText.isEmpty {
            return appState.dsaQuestions
        }
        return appState.dsaQuestions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.topics.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }

    private var filteredSwiftQuestions: [Question] {
        if searchText.isEmpty {
            return appState.swiftQuestions
        }
        return appState.swiftQuestions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.topics.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }

    private func sectionKey(_ name: String, activeTab: String) -> String {
        "\(activeTab)::\(name)"
    }

    @ViewBuilder
    private func questionRow(_ question: Question, activeTab: String) -> some View {
        let isSelected = activeTab == "dsa"
            ? appState.selectedDSAQuestion?.id == question.id
            : appState.selectedSwiftQuestion?.id == question.id
        let isSolved = appState.userActivity.solvedQuestionIds.contains(question.id)
        SidebarButton(
            title: question.title,
            icon: activeTab == "dsa"
                ? (isSelected ? "chevron.right.circle.fill" : "chevron.right.circle")
                : (isSelected ? "network" : "globe"),
            isSelected: isSelected,
            isSolved: isSolved,
            activeTab: activeTab
        ) {
            if activeTab == "dsa" {
                appState.selectedDSAQuestion = question
            } else {
                appState.selectedSwiftQuestion = question
            }
            onDSASelect(question)
        }
    }

    @ViewBuilder
    private func sectionBlock(_ section: QuestionSection, activeTab: String) -> some View {
        let key = sectionKey(section.name, activeTab: activeTab)
        let solvedInSection = section.questions.filter { appState.userActivity.solvedQuestionIds.contains($0.id) }.count
        let isExpanded = !collapsedSections.contains(key)

        VStack(alignment: .leading, spacing: 2) {
            SidebarSectionHeader(
                title: section.name,
                solvedCount: solvedInSection,
                totalCount: section.questions.count,
                accentColor: activeTab == "swiftPractice" ? .blue : .orange,
                isExpanded: Binding(
                    get: { !collapsedSections.contains(key) },
                    set: { expanded in
                        if expanded { collapsedSections.remove(key) } else { collapsedSections.insert(key) }
                    }
                )
            )

            if isExpanded {
                ForEach(section.questions) { question in
                    questionRow(question, activeTab: activeTab)
                }
            }
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Logo Banner ─────────────────────────────────────
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.35), Color.red.opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(colors: [Color.orange.opacity(0.5), Color.red.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 3)

                    Image(systemName: "swift")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.orange, Color.red],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("SwiftForge")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                    Text("DSA & iOS Studio")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.35))
                        .tracking(0.5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // ── Mode Dropdown Selector ───────────────────────────
            Menu {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.activeTab = .dsa
                        if let question = appState.selectedDSAQuestion {
                            onDSASelect(question)
                        }
                    }
                }) {
                    Label("DSA Practice", systemImage: "square.grid.3x3.fill")
                }
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.activeTab = .swiftPractice
                        if let question = appState.selectedSwiftQuestion {
                            onDSASelect(question)
                        }
                    }
                }) {
                    Label("Swift Practice", systemImage: "network")
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: appState.activeTab == .swiftPractice ? "network" : "square.grid.3x3.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(
                            appState.activeTab == .swiftPractice
                                ? LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                        )
                    
                    Text(appState.activeTab.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    LinearGradient(
                                        colors: appState.activeTab == .swiftPractice
                                            ? [Color.blue.opacity(0.4), Color.blue.opacity(0.1)]
                                            : [Color.orange.opacity(0.4), Color.orange.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.75
                                )
                        )
                )
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            // ── Search & Filter Gutter ───────────────────────────
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.35))
                
                TextField("Search questions...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .focused($isSearchFocused)

                if !searchText.isEmpty {
                    Button(action: { withAnimation(.snappy) { searchText = "" } }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        (appState.activeTab == .swiftPractice ? Color.blue : Color.orange)
                            .opacity(isSearchFocused ? 0.55 : 0),
                        lineWidth: 1.25
                    )
            )
            .shadow(
                color: (appState.activeTab == .swiftPractice ? Color.blue : Color.orange).opacity(isSearchFocused ? 0.25 : 0),
                radius: 6
            )
            .animation(.smooth, value: isSearchFocused)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            // ── Progress Stats Panel ─────────────────────────────
            let total = appState.activeTab == .dsa ? appState.dsaQuestions.count : appState.swiftQuestions.count
            let solved = appState.activeTab == .dsa 
                ? appState.dsaQuestions.filter { appState.userActivity.solvedQuestionIds.contains($0.id) }.count 
                : appState.swiftQuestions.filter { appState.userActivity.solvedQuestionIds.contains($0.id) }.count
            let percent = total > 0 ? CGFloat(solved) / CGFloat(total) : 0.0

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Solved Progress")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.4))
                    Spacer()
                    Text("\(solved)/\(total) (\(Int(percent * 100))%)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(appState.activeTab == .swiftPractice ? .cyan : .orange)
                }
                .padding(.horizontal, 16)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                appState.activeTab == .swiftPractice
                                    ? LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: geometry.size.width * percent, height: 4)
                            .shadow(color: (appState.activeTab == .swiftPractice ? Color.blue : Color.orange).opacity(0.6), radius: 3)
                            .animation(.smooth, value: percent)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)
            .pulseOnChange(solved)

            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
                .padding(.horizontal, 12)

            // ── Question List (Filtered by Active Tab) ───
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if appState.activeTab == .dsa {
                        // ── DSA Section ──
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 5, height: 5)
                                    .shadow(color: .orange.opacity(0.6), radius: 3)
                                Text("DSA CHALLENGES")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(Color.white.opacity(0.3))
                                    .tracking(1.0)
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 6)

                            if searchText.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(QuestionSectionizer.grouped(filteredDSAQuestions, category: "dsa"), id: \.name) { section in
                                        sectionBlock(section, activeTab: "dsa")
                                    }
                                }
                            } else {
                                ForEach(filteredDSAQuestions) { question in
                                    questionRow(question, activeTab: "dsa")
                                }
                            }

                            if filteredDSAQuestions.isEmpty {
                                Text("No challenges found")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 8)
                            }
                        }
                    } else {
                        // ── Swift Practice Section ──
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 5, height: 5)
                                    .shadow(color: .blue.opacity(0.6), radius: 3)
                                Text("SWIFT PRACTICE")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(Color.white.opacity(0.3))
                                    .tracking(1.0)
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 6)

                            if searchText.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(QuestionSectionizer.grouped(filteredSwiftQuestions, category: "swiftPractice"), id: \.name) { section in
                                        sectionBlock(section, activeTab: "swiftPractice")
                                    }
                                }
                            } else {
                                ForEach(filteredSwiftQuestions) { question in
                                    questionRow(question, activeTab: "swiftPractice")
                                }
                            }

                            if filteredSwiftQuestions.isEmpty {
                                Text("No challenges found")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 8)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }

            Spacer()

            // ── Footer ──────────────────────────────────────────
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
                .padding(.horizontal, 12)

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 14, height: 14)
                        .scaleEffect(statusPulse ? 1.5 : 1.0)
                        .opacity(statusPulse ? 0.0 : 0.6)
                        .animation(Animation.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: statusPulse)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                        .shadow(color: Color.green.opacity(0.8), radius: 3)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Local Engine Active")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.8))
                    Text("Swift 6.0  ·  Resilient Core")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        #if os(macOS)
        .frame(width: 210)
        .frame(maxHeight: .infinity)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .background(
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.09)
                
                // Deep top accent glow
                LinearGradient(
                    colors: [
                        (appState.activeTab == .swiftPractice ? Color.blue : Color.orange).opacity(0.06),
                        Color.clear
                    ],
                    startPoint: .top, endPoint: .center
                )
            }
        )
        .onAppear { statusPulse = true }
    }
}
