import SwiftUI

public struct DSASolutionView: View {
    let question: Question?
    let isFocused: Bool
    let onToggleFocus: (() -> Void)?
    let onInsertToEditor: () -> Void
    
    @State private var copiedToClipboard = false
    @State private var insertedToEditor = false
    
    public init(question: Question?, isFocused: Bool = false, onToggleFocus: (() -> Void)? = nil, onInsertToEditor: @escaping () -> Void = {}) {
        self.question = question
        self.isFocused = isFocused
        self.onToggleFocus = onToggleFocus
        self.onInsertToEditor = onInsertToEditor
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let question = question {
                    // Header Title
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.orange)
                            
                            Text("Official Solution")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if let onToggleFocus = onToggleFocus {
                                Button(action: onToggleFocus) {
                                    HStack(spacing: 4) {
                                        Image(systemName: isFocused ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                            .font(.system(size: 10, weight: .bold))
                                        Text(isFocused ? "Exit Full Screen" : "Full Screen Solution")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundColor(isFocused ? .orange : Color(white: 0.7))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(isFocused ? Color.orange.opacity(0.15) : Color.white.opacity(0.08))
                                    .cornerRadius(5)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(isFocused ? Color.orange.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 0.75)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        Text(question.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(white: 0.65))
                    }
                    
                    // Action Buttons (Copy & Insert)
                    HStack(spacing: 10) {
                        Button(action: copySolution) {
                            HStack(spacing: 5) {
                                Image(systemName: copiedToClipboard ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                    .font(.system(size: 11))
                                Text(copiedToClipboard ? "Copied!" : "Copy Solution")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(copiedToClipboard ? .green : .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(copiedToClipboard ? Color.green.opacity(0.15) : Color.white.opacity(0.08))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(copiedToClipboard ? Color.green.opacity(0.4) : Color.white.opacity(0.15), lineWidth: 0.75)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: insertToEditor) {
                            HStack(spacing: 5) {
                                Image(systemName: insertedToEditor ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                                    .font(.system(size: 11))
                                Text(insertedToEditor ? "Inserted to Editor!" : "Insert to Editor")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                            )
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.orange.opacity(0.35), lineWidth: 0.75)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // Solution Code Box
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SWIFT REFERENCE IMPLEMENTATION")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(white: 0.45))
                        
                        ScrollView([.horizontal, .vertical]) {
                            Text(question.solutionCode)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundColor(Color(red: 0.88, green: 0.92, blue: 0.96))
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .background(Color(red: 0.08, green: 0.09, blue: 0.12))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                } else {
                    Text("No question selected.")
                        .foregroundColor(.gray)
                }
            }
            .padding(16)
        }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copiedToClipboard = false }
        }
    }
    
    private func insertToEditor() {
        onInsertToEditor()
        withAnimation { insertedToEditor = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { insertedToEditor = false }
        }
    }
}
