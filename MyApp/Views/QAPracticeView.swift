import SwiftUI

/// Q&A Practice: a question paired with a deeply-explained answer — prose
/// explanation, a runnable Swift code example, and bullet-point takeaways.
/// A reading/comprehension format, not a quiz — no options, no scoring,
/// just "did I open and read this" progress tracking. Structurally mirrors
/// MCQPracticeView (single scrollable card + Previous/Next), but the card
/// itself is a multi-section reading layout instead of tappable options.
public struct QAPracticeView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    private var currentIndex: Int? {
        guard let item = appState.selectedQAItem else { return nil }
        return appState.qaItems.firstIndex(where: { $0.id == item.id })
    }

    private var hasPrevious: Bool {
        guard let idx = currentIndex else { return false }
        return idx > 0
    }

    private var hasNext: Bool {
        guard let idx = currentIndex else { return false }
        return idx < appState.qaItems.count - 1
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            Divider().background(Color.white.opacity(0.06))

            if let item = appState.selectedQAItem {
                ScrollView {
                    QAItemCard(item: item)
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
        .forgeCanvas(Surface.base, glow: .yellow, glowIntensity: 0.05)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Q&A Practice")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                if let idx = currentIndex {
                    Text("Question \(idx + 1) of \(appState.qaItems.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.4))
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 11))
                Text("\(appState.qaViewedCount)/\(appState.qaItems.count) read")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.yellow.opacity(0.08))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.yellow.opacity(0.25), lineWidth: 0.75)
            )
            .pulseOnChange(appState.qaViewedCount)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Surface.raised)
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
                        ? LinearGradient(colors: [Color.yellow, Color.indigo], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.white.opacity(0.25)], startPoint: .leading, endPoint: .trailing)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.indigo.opacity(0.15))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.indigo.opacity(0.3), lineWidth: 0.75)
                )
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!hasNext)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Surface.raised)
    }

    private var emptyState: some View {
        ForgeEmptyState(icon: "text.book.closed", title: "No Q&A items available", accent: .yellow)
    }

    private func goToNext() {
        guard let idx = currentIndex, idx + 1 < appState.qaItems.count else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            appState.selectedQAItem = appState.qaItems[idx + 1]
        }
    }

    private func goToPrevious() {
        guard let idx = currentIndex, idx - 1 >= 0 else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            appState.selectedQAItem = appState.qaItems[idx - 1]
        }
    }
}

/// One Q&A entry: question, topic tags, explanation prose, a styled code
/// example block, and bullet-point key takeaways. No local `@State` at all
/// (nothing to answer/toggle here) — the parent's `.id(item.id)` still keeps
/// scroll position sane when switching items since it's a fresh view.
private struct QAItemCard: View {
    let item: QAItem

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !item.topics.isEmpty {
                HStack(spacing: 6) {
                    ForEach(item.topics, id: \.self) { topic in
                        Text(topic.uppercased())
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(Color.yellow.opacity(0.85))
                            .tracking(0.6)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.12))
                            .cornerRadius(5)
                    }
                }
            }

            Text(item.question)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            Divider().background(Color.white.opacity(0.08))

            sectionLabel("EXPLANATION", icon: "text.alignleft", color: .yellow)
            Text(item.explanation)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color.white.opacity(0.85))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            sectionLabel("EXAMPLE", icon: "chevron.left.forwardslash.chevron.right", color: .indigo)
            codeBlock(item.example)

            if !item.keyTakeaways.isEmpty {
                sectionLabel("KEY TAKEAWAYS", icon: "checklist", color: .green)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(item.keyTakeaways.enumerated()), id: \.offset) { _, point in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.green.opacity(0.8))
                                .padding(.top, 1)
                            Text(point)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.8))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(20)
        .glassCard()
    }

    private func sectionLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 10, weight: .black))
                .foregroundColor(color)
                .tracking(0.8)
        }
    }

    private func codeBlock(_ code: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(red: 0.85, green: 0.9, blue: 0.95))
                .padding(14)
                .fixedSize(horizontal: true, vertical: true)
        }
        .background(Color.black.opacity(0.35))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.indigo.opacity(0.25), lineWidth: 0.75)
        )
    }
}
