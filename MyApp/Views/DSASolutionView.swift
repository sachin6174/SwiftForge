import SwiftUI

public struct DSASolutionView: View {
    let question: Question?
    let isFocused: Bool
    let onToggleFocus: (() -> Void)?
    let onInsertToEditor: () -> Void
    
    @State private var copiedToClipboard = false
    @State private var insertedToEditor = false
    @State private var isHoveringCopy = false
    @State private var isHoveringInsert = false
    
    public init(question: Question?, isFocused: Bool = false, onToggleFocus: (() -> Void)? = nil, onInsertToEditor: @escaping () -> Void = {}) {
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
                    HStack(spacing: 12) {
                        // Copy Button
                        Button(action: copySolution) {
                            HStack(spacing: 6) {
                                Image(systemName: copiedToClipboard ? "checkmark.circle.fill" : "doc.on.doc")
                                    .font(.system(size: 11, weight: .bold))
                                Text(copiedToClipboard ? "Copied!" : "Copy Code")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(copiedToClipboard ? .green : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(copiedToClipboard ? Color.green.opacity(0.12) : Color.white.opacity(0.04))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(copiedToClipboard ? Color.green.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 0.75)
                            )
                            .scaleEffect(isHoveringCopy ? 1.02 : 1.0)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .onHover { over in
                            withAnimation(.easeOut(duration: 0.15)) { isHoveringCopy = over }
                        }
                        
                        // Insert to Editor Button
                        Button(action: insertToEditor) {
                            HStack(spacing: 6) {
                                Image(systemName: insertedToEditor ? "checkmark.circle.fill" : "arrow.right.to.line.compact")
                                    .font(.system(size: 11, weight: .bold))
                                Text(insertedToEditor ? "Inserted!" : "Insert to Editor")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.orange, Color.red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: Color.orange.opacity(isHoveringInsert ? 0.45 : 0.25), radius: 6, x: 0, y: 3)
                            .scaleEffect(isHoveringInsert ? 1.02 : 1.0)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .onHover { over in
                            withAnimation(.easeOut(duration: 0.15)) { isHoveringInsert = over }
                        }
                    }
                    
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
        .background(Color(red: 0.08, green: 0.09, blue: 0.12))
    }
    
    private func copySolution() {
        guard let code = question?.solutionCode else { return }
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = code
        #endif
        
        withAnimation { copiedToClipboard = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copiedToClipboard = false }
        }
    }
    
    private func insertToEditor() {
        onInsertToEditor()
        withAnimation { insertedToEditor = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { insertedToEditor = false }
        }
    }
}
