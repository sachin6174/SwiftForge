import SwiftUI

public struct ConsoleView: View {
    let output: String
    let compilerError: String?

    @State private var isCopied = false
    
    public init(output: String, compilerError: String?) {
        self.output = output
        self.compilerError = compilerError
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "terminal.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Console Output")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()

                // Open Log File button
                Button(action: {
                    let logPath = LoggerService.shared.getLogFilePath()
                    NSWorkspace.shared.open(URL(fileURLWithPath: logPath))
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 10, weight: .medium))
                        Text("app_test.log")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(Color.cyan.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.12))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 0.75)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Copy button
                Button(action: {
                    let textToCopy = compilerError ?? output
                    if !textToCopy.isEmpty {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(textToCopy, forType: .string)
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
                    .foregroundColor(isCopied ? .green : .white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isCopied ? Color.green.opacity(0.15) : Color.white.opacity(0.06))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isCopied ? Color.green.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 0.75)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(red: 0.1, green: 0.11, blue: 0.14))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if let compilerError = compilerError {
                        Text(compilerError)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.red)
                    } else {
                        Text(output)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(2)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.black.opacity(0.95))
        }
        .frame(height: 150)
    }
}
