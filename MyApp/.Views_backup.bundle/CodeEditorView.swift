import SwiftUI

public struct CodeEditorView: View {
    @Binding var code: String
    let fileName: String
    
    public init(code: Binding<String>, fileName: String) {
        self._code = code
        self.fileName = fileName
    }
    
    var lineCount: Int {
        let lines = code.components(separatedBy: .newlines)
        return max(1, lines.count)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Tab File Name
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(fileName)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(red: 0.07, green: 0.07, blue: 0.09))
                
                Spacer()
                
                Text("Swift 6.0")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .padding(.trailing, 12)
            }
            .background(Color(red: 0.1, green: 0.11, blue: 0.14))
            
            // Editor Area
            HStack(alignment: .top, spacing: 0) {
                // Line Numbers
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(Array(1...lineCount), id: \.self) { line in
                        Text("\(line)")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(Color.gray.opacity(0.4))
                            .frame(height: 20)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .frame(width: 32)
                .background(Color(red: 0.05, green: 0.05, blue: 0.07))
                
                // Text Editor
                TextEditor(text: $code)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.white)
                    .accentColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.07, green: 0.07, blue: 0.09))
                    .scrollContentBackground(.hidden)
            }
            .frame(maxHeight: .infinity)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.09))
    }
}
