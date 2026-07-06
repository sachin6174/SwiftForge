import SwiftUI

public struct SidebarView: View {
    @ObservedObject var appState: AppState
    let onDSASelect: (Question) -> Void

    @State private var statusPulse = false

    public init(appState: AppState, onDSASelect: @escaping (Question) -> Void) {
        self.appState = appState
        self.onDSASelect = onDSASelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Logo Banner ─────────────────────────────────────
            HStack(spacing: 11) {
                ZStack {
                    // Glow capsule behind icon
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.28), Color.red.opacity(0.18)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.orange.opacity(0.25), lineWidth: 0.75)
                        )
                        .shadow(color: Color.orange.opacity(0.25), radius: 8)

                    Image(systemName: "swift")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.orange, Color.red],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("SwiftForge")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("DSA & iOS Studio")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.38))
                        .tracking(0.3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 10)

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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(
                            appState.activeTab == .swiftPractice
                                ? LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                        )
                    
                    Text(appState.activeTab.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(white: 0.45))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    appState.activeTab == .swiftPractice
                                        ? Color.blue.opacity(0.35)
                                        : Color.orange.opacity(0.35),
                                    lineWidth: 0.75
                                )
                        )
                )
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            // Separator
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
                .padding(.horizontal, 10)

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
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Color(white: 0.38))
                                    .tracking(1.2)
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 4)

                            ForEach(appState.dsaQuestions) { question in
                                let isSelected = appState.selectedDSAQuestion?.id == question.id
                                SidebarButton(
                                    title: question.title,
                                    icon: isSelected ? "chevron.right.circle.fill" : "chevron.right.circle",
                                    isSelected: isSelected
                                ) {
                                    appState.selectedDSAQuestion = question
                                    onDSASelect(question)
                                }
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
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Color(white: 0.38))
                                    .tracking(1.2)
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 4)

                            ForEach(appState.swiftQuestions) { question in
                                let isSelected = appState.selectedSwiftQuestion?.id == question.id
                                SidebarButton(
                                    title: question.title,
                                    icon: isSelected ? "network" : "globe",
                                    isSelected: isSelected
                                ) {
                                    appState.selectedSwiftQuestion = question
                                    onDSASelect(question)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }

            Spacer()

            // ── Footer ──────────────────────────────────────────
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
                .padding(.horizontal, 10)

            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.25))
                        .frame(width: 14, height: 14)
                        .scaleEffect(statusPulse ? 1.4 : 1.0)
                        .opacity(statusPulse ? 0.0 : 0.6)
                        .animation(Animation.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: statusPulse)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                        .shadow(color: Color.green.opacity(0.7), radius: 3)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Local Compiler Active")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(white: 0.7))
                    Text("Swift 6.0  ·  Resilient DB")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(white: 0.3))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        #if os(macOS)
        .frame(width: 210)
        #else
        .frame(maxWidth: .infinity)
        #endif
        .background(
            ZStack {
                Color(red: 0.065, green: 0.072, blue: 0.092)
                // Subtle top gradient shimmer
                LinearGradient(
                    colors: [Color.orange.opacity(0.04), Color.clear],
                    startPoint: .top, endPoint: .center
                )
            }
        )
        .onAppear { statusPulse = true }
    }
}

