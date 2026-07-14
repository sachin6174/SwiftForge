import SwiftUI

/// Projects: full take-home/portfolio app specs — "build a whole app" style
/// assignments — as opposed to a single-function DSA problem or a scoped
/// Machine Round exercise. Read-only reference material, structurally
/// mirroring QAPracticeView (single scrollable card + Previous/Next): there's
/// no code editor/runner here either, since this app's console executes
/// single-file Swift scripts, not multi-view SwiftUI/UIKit apps.
public struct ProjectsPracticeView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    private var currentIndex: Int? {
        guard let item = appState.selectedProjectItem else { return nil }
        return appState.projectItems.firstIndex(where: { $0.id == item.id })
    }

    private var hasPrevious: Bool {
        guard let idx = currentIndex else { return false }
        return idx > 0
    }

    private var hasNext: Bool {
        guard let idx = currentIndex else { return false }
        return idx < appState.projectItems.count - 1
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            Divider().background(Color.white.opacity(0.06))

            if let item = appState.selectedProjectItem {
                ScrollView {
                    ProjectItemCard(item: item)
                        .id(item.id)
                        .padding(24)
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                }

                Divider().background(Color.white.opacity(0.06))

                navigationBar
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.08, green: 0.09, blue: 0.12))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Projects")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                if let idx = currentIndex {
                    Text("Project \(idx + 1) of \(appState.projectItems.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.4))
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.pink)
                    .font(.system(size: 11))
                Text("\(appState.projectViewedCount)/\(appState.projectItems.count) reviewed")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.pink.opacity(0.08))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.pink.opacity(0.25), lineWidth: 0.75)
            )
            .pulseOnChange(appState.projectViewedCount)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(red: 0.1, green: 0.11, blue: 0.14))
    }

    private var navigationBar: some View {
        HStack(spacing: 10) {
            Button(action: goToPrevious) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                    Text("Previous")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(hasPrevious ? Color.white.opacity(0.75) : Color.white.opacity(0.25))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.04))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.75)
                )
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!hasPrevious)

            Spacer()

            Button(action: goToNext) {
                HStack(spacing: 5) {
                    Text("Next")
                        .font(.system(size: 11, weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(
                    hasNext
                        ? LinearGradient(colors: [Color.pink, Color.purple], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.white.opacity(0.25)], startPoint: .leading, endPoint: .trailing)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.purple.opacity(0.15))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 0.75)
                )
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!hasNext)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(red: 0.1, green: 0.11, blue: 0.14))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 32))
                .foregroundColor(Color.white.opacity(0.2))
            Text("No projects available")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func goToNext() {
        guard let idx = currentIndex, idx + 1 < appState.projectItems.count else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            appState.selectedProjectItem = appState.projectItems[idx + 1]
        }
    }

    private func goToPrevious() {
        guard let idx = currentIndex, idx - 1 >= 0 else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            appState.selectedProjectItem = appState.projectItems[idx - 1]
        }
    }
}

/// One project entry: title, source (who the assignment is from), difficulty,
/// topic tags, and the full spec as prose. No local `@State` (nothing to
/// answer/toggle) — the parent's `.id(item.id)` keeps scroll position sane
/// when switching items since it's a fresh view each time.
private struct ProjectItemCard: View {
    let item: ProjectItem

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Text(item.difficulty)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(difficultyColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(difficultyColor.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(difficultyColor.opacity(0.25), lineWidth: 0.75)
                    )

                Text(item.source.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(Color.pink.opacity(0.85))
                    .tracking(0.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.pink.opacity(0.12))
                    .cornerRadius(5)
            }

            if !item.topics.isEmpty {
                HStack(spacing: 6) {
                    ForEach(item.topics, id: \.self) { topic in
                        Text(topic)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.65))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                    }
                }
            }

            Text(item.title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            Divider().background(Color.white.opacity(0.08))

            Text(item.description)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color.white.opacity(0.85))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(20)
        .glassCard()
    }

    private var difficultyColor: Color {
        switch item.difficulty.lowercased() {
        case "easy": return Color(red: 0.3, green: 0.8, blue: 0.4)
        case "medium": return Color(red: 1.0, green: 0.6, blue: 0.1)
        case "hard": return Color(red: 1.0, green: 0.25, blue: 0.3)
        default: return .pink
        }
    }
}
