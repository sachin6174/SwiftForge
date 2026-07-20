import SwiftUI

public struct SidebarView: View {
    @ObservedObject var appState: AppState
    let onDSASelect: (Question) -> Void

    @State private var statusPulse = false
    @State private var searchText = ""
    @State private var isHoveringHeader = false
    @State private var collapsedSections: Set<String> = []
    @State private var expandedQuestionPreviews: Set<String> = []
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

    private var filteredMCQQuestions: [MCQQuestion] {
        if searchText.isEmpty {
            return appState.mcqQuestions
        }
        return appState.mcqQuestions.filter {
            $0.question.localizedCaseInsensitiveContains(searchText) ||
            $0.topics.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }

    private var filteredMachineRoundQuestions: [Question] {
        if searchText.isEmpty {
            return appState.machineRoundQuestions
        }
        return appState.machineRoundQuestions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.topics.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }

    private var filteredQAItems: [QAItem] {
        if searchText.isEmpty {
            return appState.qaItems
        }
        return appState.qaItems.filter {
            $0.question.localizedCaseInsensitiveContains(searchText) ||
            $0.topics.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }

    private var filteredProjectItems: [ProjectItem] {
        if searchText.isEmpty {
            return appState.projectItems
        }
        return appState.projectItems.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.source.localizedCaseInsensitiveContains(searchText) ||
            $0.topics.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }

    private func sectionKey(_ name: String, activeTab: String) -> String {
        "\(activeTab)::\(name)"
    }

    // Sourced from the single TabAccents palette in DesignSystem.swift — see
    // ContentView's activeAccentColor/activeAccentGradient/headerIconName
    // for the matching cleanup there. These three used plain system
    // .blue/.cyan for Swift Practice where ContentView/DSASolutionView used
    // a richer custom blue→cyan; now all four agree.
    private var modePickerIconName: String {
        appState.activeTab.accent.icon
    }

    private var modePickerGradient: LinearGradient {
        appState.activeTab.accent.gradient
    }

    private var modePickerStrokeColors: [Color] {
        appState.activeTab.accent.strokeGradientColors
    }

    /// Not computed inline in `body` — a plain (non-View-returning) `switch`
    /// statement inside a `@ViewBuilder` gets transformed by the result
    /// builder like every other statement there, which requires each branch
    /// to produce a `View` (`buildEither`); since these branches only assign
    /// plain values, that fails with "type '()' cannot conform to 'View'".
    /// A regular function call sidesteps the builder entirely.
    private func progressStats() -> (total: Int, solved: Int, label: String) {
        switch appState.activeTab {
        case .dsa:
            let total = appState.dsaQuestions.count
            let solved = appState.dsaQuestions.filter { appState.userActivity.solvedQuestionIds.contains($0.id) }.count
            return (total, solved, "Solved Progress")
        case .swiftPractice:
            let total = appState.swiftQuestions.count
            let solved = appState.swiftQuestions.filter { appState.userActivity.solvedQuestionIds.contains($0.id) }.count
            return (total, solved, "Solved Progress")
        case .machineRound:
            let total = appState.machineRoundQuestions.count
            let solved = appState.machineRoundQuestions.filter { appState.userActivity.solvedQuestionIds.contains($0.id) }.count
            return (total, solved, "Solved Progress")
        case .mcq:
            return (appState.mcqQuestions.count, appState.mcqCorrectCount, "Correct Progress")
        case .qa:
            return (appState.qaItems.count, appState.qaViewedCount, "Read Progress")
        case .projects:
            return (appState.projectItems.count, appState.projectViewedCount, "Reviewed Progress")
        }
    }

    private var activeAccentColor: Color {
        appState.activeTab.accent.primary
    }

    private var activeAccentGradient: LinearGradient {
        appState.activeTab.accent.gradient
    }

    /// Not called inline in `questionRow`'s `@ViewBuilder` body for the same
    /// reason `progressStats()` isn't — see that function's doc comment.
    private func isQuestionSelected(_ question: Question, activeTab: String) -> Bool {
        switch activeTab {
        case "dsa": return appState.selectedDSAQuestion?.id == question.id
        case "machineRound": return appState.selectedMachineRoundQuestion?.id == question.id
        default: return appState.selectedSwiftQuestion?.id == question.id
        }
    }

    private func questionRowIcon(activeTab: String, isSelected: Bool) -> String {
        switch activeTab {
        case "dsa": return isSelected ? "chevron.right.circle.fill" : "chevron.right.circle"
        case "machineRound": return isSelected ? "gearshape.fill" : "gearshape"
        default: return isSelected ? "network" : "globe"
        }
    }

    private func selectQuestion(_ question: Question, activeTab: String) {
        switch activeTab {
        case "dsa": appState.selectedDSAQuestion = question
        case "machineRound": appState.selectedMachineRoundQuestion = question
        default: appState.selectedSwiftQuestion = question
        }
        onDSASelect(question)
    }

    @ViewBuilder
    private func questionRow(_ question: Question, activeTab: String) -> some View {
        let isSelected = isQuestionSelected(question, activeTab: activeTab)
        let isSolved = appState.userActivity.solvedQuestionIds.contains(question.id)
        SidebarButton(
            title: question.title,
            icon: questionRowIcon(activeTab: activeTab, isSelected: isSelected),
            isSelected: isSelected,
            isSolved: isSolved,
            activeTab: activeTab,
            previewText: question.description,
            isPreviewExpanded: Binding(
                get: { expandedQuestionPreviews.contains(question.id) },
                set: { expanded in
                    if expanded { expandedQuestionPreviews.insert(question.id) } else { expandedQuestionPreviews.remove(question.id) }
                }
            )
        ) {
            selectQuestion(question, activeTab: activeTab)
        }
    }

    @ViewBuilder
    private func mcqRow(_ question: MCQQuestion) -> some View {
        let isSelected = appState.selectedMCQQuestion?.id == question.id
        // Green dot only for a CORRECTLY answered question, not merely
        // attempted — matches the "mastery" meaning of the green dot on the
        // DSA/Swift rows (isSolved), rather than "touched at all".
        let isCorrect = appState.userActivity.mcqCorrectIds.contains(question.id)
        SidebarButton(
            title: question.question,
            icon: isSelected ? "questionmark.circle.fill" : "questionmark.circle",
            isSelected: isSelected,
            isSolved: isCorrect,
            activeTab: "mcq"
        ) {
            appState.selectedMCQQuestion = question
        }
    }

    @ViewBuilder
    private func qaRow(_ item: QAItem) -> some View {
        let isSelected = appState.selectedQAItem?.id == item.id
        let isRead = appState.userActivity.qaViewedIds.contains(item.id)
        SidebarButton(
            title: item.question,
            icon: isSelected ? "text.book.closed.fill" : "text.book.closed",
            isSelected: isSelected,
            isSolved: isRead,
            activeTab: "qa"
        ) {
            appState.selectedQAItem = item
        }
    }

    @ViewBuilder
    private func projectRow(_ item: ProjectItem) -> some View {
        let isSelected = appState.selectedProjectItem?.id == item.id
        let isReviewed = appState.userActivity.projectViewedIds.contains(item.id)
        SidebarButton(
            title: item.title,
            icon: isSelected ? "hammer.fill" : "hammer",
            isSelected: isSelected,
            isSolved: isReviewed,
            activeTab: "projects"
        ) {
            appState.selectedProjectItem = item
        }
    }

    private func sectionAccentColor(for activeTab: String) -> Color {
        TabAccents.forCategory(activeTab).primary
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
                accentColor: sectionAccentColor(for: activeTab),
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
                                colors: [Color.orange.opacity(0.4), Color.red.opacity(0.22)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(colors: [Color.orange.opacity(0.55), Color.red.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 1
                                )
                        )
                        // Thin inset highlight for a touch of glassy depth on
                        // the brand mark — independent of the outer stroke
                        // above, so it doesn't disturb that gradient's colors.
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
                                .padding(1)
                        )
                        .shadow(color: Color.orange.opacity(0.35), radius: 10, x: 0, y: 4)

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
                        .shadow(color: Color.orange.opacity(0.4), radius: 6)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("SwiftForge")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, .white.opacity(0.78)], startPoint: .top, endPoint: .bottom)
                        )
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

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.activeTab = .mcq
                    }
                }) {
                    Label("MCQ Practice", systemImage: "questionmark.circle.fill")
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.activeTab = .machineRound
                        if let question = appState.selectedMachineRoundQuestion {
                            onDSASelect(question)
                        }
                    }
                }) {
                    Label("Machine Round", systemImage: "gearshape.fill")
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.activeTab = .qa
                    }
                }) {
                    Label("Q&A", systemImage: "books.vertical.fill")
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.activeTab = .projects
                    }
                }) {
                    Label("Projects", systemImage: "hammer.fill")
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: modePickerIconName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(modePickerGradient)

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
                                        colors: modePickerStrokeColors,
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
                        activeAccentColor.opacity(isSearchFocused ? 0.55 : 0),
                        lineWidth: 1.25
                    )
            )
            .shadow(
                color: activeAccentColor.opacity(isSearchFocused ? 0.25 : 0),
                radius: 6
            )
            .animation(.smooth, value: isSearchFocused)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            // ── Progress Stats Panel ─────────────────────────────
            let stats = progressStats()
            let total = stats.total
            let solved = stats.solved
            let progressLabel = stats.label
            let percent = total > 0 ? CGFloat(solved) / CGFloat(total) : 0.0

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(progressLabel)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.4))
                    Spacer()
                    Text("\(solved)/\(total) (\(Int(percent * 100))%)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(activeAccentColor)
                }
                .padding(.horizontal, 16)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(activeAccentGradient)
                            .frame(width: geometry.size.width * percent, height: 4)
                            .shadow(color: activeAccentColor.opacity(0.6), radius: 3)
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
                    if appState.activeTab == .mcq {
                        // ── MCQ Practice Section ──
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 5, height: 5)
                                    .shadow(color: .purple.opacity(0.6), radius: 3)
                                Text("MCQ TRIVIA")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(Color.white.opacity(0.3))
                                    .tracking(0.8)
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 6)

                            ForEach(filteredMCQQuestions) { question in
                                mcqRow(question)
                            }

                            if filteredMCQQuestions.isEmpty {
                                Text("No questions found")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 8)
                            }
                        }
                    } else if appState.activeTab == .qa {
                        // ── Q&A Section ──
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(LinearGradient(colors: [.yellow, .indigo], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 5, height: 5)
                                    .shadow(color: .yellow.opacity(0.6), radius: 3)
                                Text("Q&A")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(Color.white.opacity(0.3))
                                    .tracking(0.8)
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 6)

                            ForEach(filteredQAItems) { item in
                                qaRow(item)
                            }

                            if filteredQAItems.isEmpty {
                                Text("No questions found")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 8)
                            }
                        }
                    } else if appState.activeTab == .projects {
                        // ── Projects Section ──
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(LinearGradient(colors: [.pink, .purple], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 5, height: 5)
                                    .shadow(color: .pink.opacity(0.6), radius: 3)
                                Text("PROJECTS")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(Color.white.opacity(0.3))
                                    .tracking(0.8)
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 6)

                            ForEach(filteredProjectItems) { item in
                                projectRow(item)
                            }

                            if filteredProjectItems.isEmpty {
                                Text("No projects found")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 8)
                            }
                        }
                    } else if appState.activeTab == .dsa {
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
                                    .tracking(0.8)
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
                    } else if appState.activeTab == .machineRound {
                        // ── Machine Round Section ──
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(LinearGradient(colors: [.mint, .teal], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 5, height: 5)
                                    .shadow(color: .mint.opacity(0.6), radius: 3)
                                Text("MACHINE ROUND")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(Color.white.opacity(0.3))
                                    .tracking(0.8)
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 6)

                            if searchText.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(QuestionSectionizer.grouped(filteredMachineRoundQuestions, category: "machineRound"), id: \.name) { section in
                                        sectionBlock(section, activeTab: "machineRound")
                                    }
                                }
                            } else {
                                ForEach(filteredMachineRoundQuestions) { question in
                                    questionRow(question, activeTab: "machineRound")
                                }
                            }

                            if filteredMachineRoundQuestions.isEmpty {
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
                                    .tracking(0.8)
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
        // Width is applied by the caller (a draggable, resizable sidebar on
        // macOS/iPad via SplitDragHandle; fills available width on iOS).
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .forgeCanvas(Surface.canvas, glow: activeAccentColor, glowIntensity: 0.06)
        .onAppear { statusPulse = true }
    }
}
