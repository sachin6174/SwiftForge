import SwiftUI

public struct ConsoleView: View {
    let output: String
    let compilerError: String?
    @State private var isCleared = false

    public init(output: String, compilerError: String?) {
        self.output = output
        self.compilerError = compilerError
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header Bar ──
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(compilerError == nil ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                        .shadow(color: (compilerError == nil ? Color.green : Color.red).opacity(0.8), radius: 4)

                    Text(compilerError == nil ? "TERMINAL CONSOLE" : "COMPILATION ERROR")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(compilerError == nil ? .green : .red)

                    Text(compilerError == nil ? "STATUS: OK" : "STATUS: FAIL")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(compilerError == nil ? .green : .red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background((compilerError == nil ? Color.green : Color.red).opacity(0.12))
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke((compilerError == nil ? Color.green : Color.red).opacity(0.25), lineWidth: 0.75)
                        )
                }

                Spacer()

                // Actions Group
                HStack(spacing: 8) {
                    // Clear / Restore Button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) { isCleared.toggle() }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isCleared ? "arrow.counterclockwise" : "trash")
                                .font(.system(size: 9, weight: .bold))
                            Text(isCleared ? "Restore" : "Clear")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.75)
                        )
                    }
                    .buttonStyle(PressableButtonStyle())

                    // Copy Button
                    CopyConsoleButton(textToCopy: compilerError ?? output)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(red: 0.1, green: 0.11, blue: 0.14))

            Divider()
                .background(Color.white.opacity(0.06))

            // ── Scrollable Console Logs ──
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        if isCleared {
                            Text("[Logs cleared. Click 'Restore' to view original outputs]")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.3))
                                .italic()
                                .padding(.top, 4)
                        } else if let error = compilerError, !error.isEmpty {
                            Text(error)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                                .lineSpacing(4)
                                .textSelection(.enabled)
                        } else {
                            Text(output)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.85))
                                .lineSpacing(4)
                                .textSelection(.enabled)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: output) { _ in
                    isCleared = false
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: compilerError) { _ in
                    isCleared = false
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.08))
        }
    }
}

// MARK: - Reusable Copy Console Button Component
struct CopyConsoleButton: View {
    let textToCopy: String
    @State private var isCopied = false

    var body: some View {
        Button(action: {
            if !textToCopy.isEmpty {
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(textToCopy, forType: .string)
                #elseif os(iOS)
                UIPasteboard.general.string = textToCopy
                #endif
                withAnimation(.easeInOut(duration: 0.15)) {
                    isCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isCopied = false
                    }
                }
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9, weight: .bold))
                Text(isCopied ? "Copied!" : "Copy")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(isCopied ? .green : Color.white.opacity(0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(isCopied ? Color.green.opacity(0.12) : Color.white.opacity(0.04))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isCopied ? Color.green.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.75)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}
