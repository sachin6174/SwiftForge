import SwiftUI

public struct ConsoleView: View {
    let output: String
    let compilerError: String?
    
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
