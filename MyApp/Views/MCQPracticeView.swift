import SwiftUI

/// Simple MCQ trivia practice: a question, four tappable options, immediate
/// color-coded feedback, and score tracking — no code editor, no test
/// harness. Distinct from the DSA/Swift workspace entirely.
public struct MCQPracticeView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    private var currentIndex: Int? {
        guard let q = appState.selectedMCQQuestion else { return nil }
        return appState.mcqQuestions.firstIndex(where: { $0.id == q.id })
    }

    private var hasPrevious: Bool {
        guard let idx = currentIndex else { return false }
        return idx > 0
    }

    private var hasNext: Bool {
        guard let idx = currentIndex else { return false }
        return idx < appState.mcqQuestions.count - 1
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            Divider().background(Color.white.opacity(0.06))

            if let question = appState.selectedMCQQuestion {
                ScrollView {
                    MCQQuestionCard(
                        question: question,
                        onAnswer: { isCorrect in
                            appState.recordMCQAnswer(questionId: question.id, isCorrect: isCorrect)
                        }
                    )
                    .id(question.id)
                    .padding(24)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }

                Divider().background(Color.white.opacity(0.06))

                navigationBar
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .forgeCanvas(Surface.base, glow: .purple, glowIntensity: 0.05)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("MCQ Practice")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                if let idx = currentIndex {
                    Text("Question \(idx + 1) of \(appState.mcqQuestions.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.4))
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 11))
                Text("\(appState.mcqCorrectCount) correct")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("· \(appState.mcqAnsweredCount)/\(appState.mcqQuestions.count) answered")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.08))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green.opacity(0.25), lineWidth: 0.75)
            )
            .pulseOnChange(appState.mcqCorrectCount)
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
                        ? LinearGradient(colors: [Color.purple, Color.pink], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.white.opacity(0.25)], startPoint: .leading, endPoint: .trailing)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.purple.opacity(0.12))
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
        .background(Surface.raised)
    }

    private var emptyState: some View {
        ForgeEmptyState(icon: "questionmark.circle", title: "No MCQ questions available", accent: .purple)
    }

    private func goToNext() {
        guard let idx = currentIndex, idx + 1 < appState.mcqQuestions.count else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            appState.selectedMCQQuestion = appState.mcqQuestions[idx + 1]
        }
    }

    private func goToPrevious() {
        guard let idx = currentIndex, idx - 1 >= 0 else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            appState.selectedMCQQuestion = appState.mcqQuestions[idx - 1]
        }
    }
}

/// One question + its four options. Local `@State` (which option is picked,
/// whether feedback is showing) is reset for free whenever the parent gives
/// this view a new `.id(question.id)` — no manual reset logic needed.
private struct MCQQuestionCard: View {
    let question: MCQQuestion
    let onAnswer: (Bool) -> Void

    @State private var selectedIndex: Int?

    private var hasAnswered: Bool { selectedIndex != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !question.topics.isEmpty {
                HStack(spacing: 6) {
                    ForEach(question.topics, id: \.self) { topic in
                        Text(topic.uppercased())
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(Color.purple.opacity(0.85))
                            .tracking(0.6)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.12))
                            .cornerRadius(5)
                    }
                }
            }

            Text(question.question)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    optionButton(index: index, text: option)
                }
            }

            if hasAnswered {
                HStack(spacing: 6) {
                    Image(systemName: selectedIndex == question.correctAnswerIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(selectedIndex == question.correctAnswerIndex ? .green : .red)
                    Text(selectedIndex == question.correctAnswerIndex ? "Correct!" : "Not quite — correct answer is highlighted above")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(selectedIndex == question.correctAnswerIndex ? .green : .red)
                }
                .transition(.opacity)
            }
        }
        .padding(20)
        .glassCard()
        .animation(.easeInOut(duration: 0.2), value: selectedIndex)
    }

    private func optionButton(index: Int, text: String) -> some View {
        let isCorrectOption = index == question.correctAnswerIndex
        let isPickedOption = selectedIndex == index
        let letter = ["A", "B", "C", "D"][safe: index] ?? "\(index + 1)"

        return Button(action: {
            guard !hasAnswered else { return }
            selectedIndex = index
            onAnswer(isCorrectOption)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(optionBadgeColor(isCorrectOption: isCorrectOption, isPickedOption: isPickedOption))
                        .frame(width: 22, height: 22)
                    if hasAnswered && isCorrectOption {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    } else if hasAnswered && isPickedOption {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text(letter)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Text(text)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(hasAnswered && !isCorrectOption && !isPickedOption ? 0.4 : 0.9))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(optionFillColor(isCorrectOption: isCorrectOption, isPickedOption: isPickedOption))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(optionStrokeColor(isCorrectOption: isCorrectOption, isPickedOption: isPickedOption), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.985))
        .disabled(hasAnswered)
    }

    private func optionFillColor(isCorrectOption: Bool, isPickedOption: Bool) -> Color {
        guard hasAnswered else { return Color.white.opacity(0.04) }
        if isCorrectOption { return Color.green.opacity(0.15) }
        if isPickedOption { return Color.red.opacity(0.12) }
        return Color.white.opacity(0.02)
    }

    private func optionStrokeColor(isCorrectOption: Bool, isPickedOption: Bool) -> Color {
        guard hasAnswered else { return Color.white.opacity(0.08) }
        if isCorrectOption { return Color.green.opacity(0.5) }
        if isPickedOption { return Color.red.opacity(0.5) }
        return Color.white.opacity(0.05)
    }

    private func optionBadgeColor(isCorrectOption: Bool, isPickedOption: Bool) -> Color {
        guard hasAnswered else { return Color.white.opacity(0.08) }
        if isCorrectOption { return Color.green }
        if isPickedOption { return Color.red }
        return Color.white.opacity(0.06)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
