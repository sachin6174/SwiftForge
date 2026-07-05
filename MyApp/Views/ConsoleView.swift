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
            // Header bar
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(compilerError == nil ? Color.green : Color.red)
                        .frame(width: 7, height: 7)

                    Text(compilerError == nil ? "CONSOLE OUTPUT" : "COMPILATION ERROR")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(compilerError == nil ? .green : .red)

                    Text(compilerError == nil ? "EXIT 0" : "EXIT 1")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(compilerError == nil ? .green : .red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(compilerError == nil ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .cornerRadius(4)
                }

                Spacer()

                // Clear / Reset Terminal
                Button(action: {
                    withAnimation { isCleared.toggle() }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                        Text(isCleared ? "Restore" : "Clear")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(Color(white: 0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Copy button
                CopyConsoleButton(textToCopy: compilerError ?? output)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(red: 0.10, green: 0.12, blue: 0.15))

            Divider()
                .background(Color.white.opacity(0.08))

            // Console output display area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if isCleared {
                            Text("[Terminal output cleared. Click 'Restore' to view.]")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(white: 0.4))
                                .italic()
                        } else if let error = compilerError, !error.isEmpty {
                            Text(error)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                                .textSelection(.enabled)
                        } else {
                            Text(output)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(white: 0.85))
                                .textSelection(.enabled)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: output) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: compilerError) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .background(Color(red: 0.07, green: 0.08, blue: 0.11))
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
                    .font(.system(size: 10, weight: .medium))
                Text(isCopied ? "Copied!" : "Copy")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isCopied ? .green : Color(white: 0.5))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.06))
            .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
