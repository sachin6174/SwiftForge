import SwiftUI

public struct DSASolutionView: View {
    let question: Question?
    let isFocused: Bool
    let onToggleFocus: (() -> Void)?
    let onInsertToEditor: (String) -> Void

    @State private var copiedToClipboard = false
    @State private var insertedToEditor = false
    @State private var isHoveringCopy = false
    @State private var isHoveringInsert = false

    @State private var alternateCopiedToClipboard = false
    @State private var alternateInsertedToEditor = false
    @State private var isHoveringAlternateCopy = false
    @State private var isHoveringAlternateInsert = false

    /// "Insert to Editor" previously always used the DSA orange/red
    /// gradient regardless of which tab the question belongs to — a visibly
    /// wrong brand color when viewing a Swift Practice or Machine Round
    /// solution (blue/mint elsewhere in those tabs, orange only here).
    private var accentGradient: LinearGradient {
        switch question?.category {
        case "swiftPractice":
            return LinearGradient(colors: [Color(red: 0.1, green: 0.6, blue: 1.0), Color(red: 0.0, green: 0.85, blue: 0.9)], startPoint: .leading, endPoint: .trailing)
        case "machineRound":
            return LinearGradient(colors: [Color.mint, Color.teal], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing)
        }
    }

    private var accentShadowColor: Color {
        switch question?.category {
        case "swiftPractice": return .blue
        case "machineRound": return .mint
        default: return .orange
        }
    }

    public init(question: Question?, isFocused: Bool = false, onToggleFocus: (() -> Void)? = nil, onInsertToEditor: @escaping (String) -> Void = { _ in }) {
        self.question = question
        self.isFocused = isFocused
        self.onToggleFocus = onToggleFocus
        self.onInsertToEditor = onInsertToEditor
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let question = question {
                    // ── Header Title & Actions ──
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.yellow)
                                    .shadow(color: .yellow.opacity(0.5), radius: 5)
                                
                                Text("Reference Solution")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            Text(question.title)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.45))
                        }
                        
                        Spacer()
                        
                        if let onToggleFocus = onToggleFocus {
                            Button(action: onToggleFocus) {
                                HStack(spacing: 5) {
                                    Image(systemName: isFocused ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(isFocused ? "Exit Full" : "Full Screen")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(isFocused ? .orange : Color.white.opacity(0.7))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(isFocused ? Color.orange.opacity(0.15) : Color.white.opacity(0.04))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isFocused ? Color.orange.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 0.75)
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                    .padding(.bottom, 6)
                    
                    // ── Action Buttons ──
                    actionButtons(
                        code: question.solutionCode,
                        copied: $copiedToClipboard,
                        inserted: $insertedToEditor,
                        hoveringCopy: $isHoveringCopy,
                        hoveringInsert: $isHoveringInsert
                    )

                    Divider()
                        .background(Color.white.opacity(0.08))

                    // ── Solution Code Block ──
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SWIFT REFERENCE CODE")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(Color.white.opacity(0.35))
                            .tracking(0.5)

                        ScrollView([.horizontal, .vertical]) {
                            Text(SyntaxHighlightingEngine.highlight(code: question.solutionCode))
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .background(Color(red: 0.04, green: 0.05, blue: 0.07))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.75)
                        )
                    }

                    // ── Alternate Solution Code Block (e.g. a follow-up
                    // complexity target) — shown in its own box, separate
                    // from the graded reference solution above. ──
                    if let alternateCode = question.alternateSolutionCode {
                        Divider()
                            .background(Color.white.opacity(0.08))

                        actionButtons(
                            code: alternateCode,
                            copied: $alternateCopiedToClipboard,
                            inserted: $alternateInsertedToEditor,
                            hoveringCopy: $isHoveringAlternateCopy,
                            hoveringInsert: $isHoveringAlternateInsert
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text((question.alternateSolutionTitle ?? "ALTERNATE SOLUTION").uppercased())
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(Color.white.opacity(0.35))
                                .tracking(0.5)

                            ScrollView([.horizontal, .vertical]) {
                                Text(SyntaxHighlightingEngine.highlight(code: alternateCode))
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .background(Color(red: 0.04, green: 0.05, blue: 0.07))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 0.75)
                            )
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "lightbulb.slash")
                            .font(.system(size: 32))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No question selected")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                }
            }
            .padding(18)
        }
        .id(question?.id ?? "empty")
        .background(Color(red: 0.08, green: 0.09, blue: 0.12))
    }
    
    @ViewBuilder
    private func actionButtons(code: String, copied: Binding<Bool>, inserted: Binding<Bool>, hoveringCopy: Binding<Bool>, hoveringInsert: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            // Copy Button
            Button(action: { copyCode(code, copied: copied) }) {
                HStack(spacing: 6) {
                    Image(systemName: copied.wrappedValue ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(size: 11, weight: .bold))
                    Text(copied.wrappedValue ? "Copied!" : "Copy Code")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(copied.wrappedValue ? .green : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(copied.wrappedValue ? Color.green.opacity(0.12) : Color.white.opacity(0.04))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(copied.wrappedValue ? Color.green.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 0.75)
                )
                .scaleEffect(hoveringCopy.wrappedValue ? 1.02 : 1.0)
            }
            .buttonStyle(PressableButtonStyle())
            .onHover { over in
                withAnimation(.easeOut(duration: 0.15)) { hoveringCopy.wrappedValue = over }
            }

            // Insert to Editor Button
            Button(action: { insertCode(code, inserted: inserted) }) {
                HStack(spacing: 6) {
                    Image(systemName: inserted.wrappedValue ? "checkmark.circle.fill" : "arrow.right.to.line.compact")
                        .font(.system(size: 11, weight: .bold))
                    Text(inserted.wrappedValue ? "Inserted!" : "Insert to Editor")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentGradient)
                )
                .shadow(color: accentShadowColor.opacity(hoveringInsert.wrappedValue ? 0.45 : 0.25), radius: 6, x: 0, y: 3)
                .scaleEffect(hoveringInsert.wrappedValue ? 1.02 : 1.0)
            }
            .buttonStyle(PressableButtonStyle())
            .onHover { over in
                withAnimation(.easeOut(duration: 0.15)) { hoveringInsert.wrappedValue = over }
            }
        }
    }

    private func copyCode(_ code: String, copied: Binding<Bool>) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = code
        #endif

        withAnimation { copied.wrappedValue = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copied.wrappedValue = false }
        }
    }

    private func insertCode(_ code: String, inserted: Binding<Bool>) {
        onInsertToEditor(code)
        withAnimation { inserted.wrappedValue = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { inserted.wrappedValue = false }
        }
    }
}
