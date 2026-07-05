import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

public struct CodeEditorView: View {
    @Binding var code: String
    let fileName: String
    let isFocused: Bool
    let onToggleFocus: (() -> Void)?
    
    public init(code: Binding<String>, fileName: String, isFocused: Bool = false, onToggleFocus: (() -> Void)? = nil) {
        self._code = code
        self.fileName = fileName
        self.isFocused = isFocused
        self.onToggleFocus = onToggleFocus
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(fileName)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    
                    if isFocused {
                        Text("FULL SCREEN")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(red: 0.07, green: 0.07, blue: 0.09))
                
                Spacer()
                
                if let onToggleFocus = onToggleFocus {
                    Button(action: onToggleFocus) {
                        HStack(spacing: 4) {
                            Image(systemName: isFocused ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                            Text(isFocused ? "Exit Full Screen" : "Full Screen Editor")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(isFocused ? .orange : Color(white: 0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isFocused ? Color.orange.opacity(0.15) : Color.white.opacity(0.06))
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isFocused ? Color.orange.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 0.75)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 8)
                }
                
                Text("Swift 6.0")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(white: 0.45))
                    .padding(.trailing, 12)
            }
            .background(Color(red: 0.1, green: 0.11, blue: 0.14))
            
            // Syntax Highlighting Editor & Line Numbers Gutter
            HStack(alignment: .top, spacing: 0) {
                // Line Numbers Gutter
                let lineCount = max(1, code.components(separatedBy: .newlines).count)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(1...lineCount, id: \.self) { line in
                            Text("\(line)")
                                .font(.system(size: 13, weight: .regular, design: .monospaced))
                                .foregroundColor(Color(white: 0.35))
                                .frame(height: 18, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 0)
                    .padding(.horizontal, 6)
                }
                .frame(width: 38)
                .background(Color(red: 0.05, green: 0.05, blue: 0.07))
                .disabled(true)
                
                Divider()
                    .background(Color.white.opacity(0.06))

                #if os(macOS)
                MacCodeEditor(text: $code)
                    .frame(maxHeight: .infinity)
                #else
                TextEditor(text: $code)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color(red: 0.07, green: 0.07, blue: 0.09))
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .frame(maxHeight: .infinity)
                #endif
            }
            .frame(maxHeight: .infinity)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.09))
    }
}

#if os(macOS)
// MARK: - Mac NSTextView Representable with Syntax Highlighting & Line Numbers
struct MacCodeEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentSize = scrollView.contentSize
        let textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        textView.backgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
        textView.textColor = NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.insertionPointColor = NSColor.orange
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true

        textView.delegate = context.coordinator

        scrollView.documentView = textView

        // Initial Highlighting
        context.coordinator.applyHighlighting(to: textView, text: text)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            context.coordinator.applyHighlighting(to: textView, text: text)
            textView.selectedRanges = selectedRanges
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacCodeEditor
        var isUpdating = false

        init(_ parent: MacCodeEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isUpdating else { return }
            
            let newText = textView.string
            parent.text = newText
            
            let selectedRanges = textView.selectedRanges
            applyHighlighting(to: textView, text: newText)
            textView.selectedRanges = selectedRanges
        }

        func applyHighlighting(to textView: NSTextView, text: String) {
            isUpdating = true
            defer { isUpdating = false }

            let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            let boldFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)

            // Theme Colors (LeetCode Dark Palette)
            let defaultColor = NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)      // Off-white
            let keywordColor = NSColor(red: 0.33, green: 0.61, blue: 0.94, alpha: 1.0)      // LeetCode Cyan/Blue (#569CD6)
            let typeColor = NSColor(red: 0.30, green: 0.78, blue: 0.69, alpha: 1.0)         // LeetCode Emerald Teal (#4EC9B0)
            let stringColor = NSColor(red: 0.80, green: 0.56, blue: 0.47, alpha: 1.0)       // Warm Amber/Orange (#CE9178)
            let numberColor = NSColor(red: 0.70, green: 0.80, blue: 0.65, alpha: 1.0)       // Lime Green (#B5CEA8)
            let commentColor = NSColor(red: 0.41, green: 0.60, blue: 0.33, alpha: 1.0)      // Muted Green/Gray (#6A9955)
            let funcColor = NSColor(red: 0.86, green: 0.86, blue: 0.66, alpha: 1.0)         // Soft Gold (#DCDCAA)

            let attributed = NSMutableAttributedString(
                string: text,
                attributes: [
                    .font: font,
                    .foregroundColor: defaultColor
                ]
            )

            let range = NSRange(location: 0, length: text.utf16.count)

            // Regex 1: Keywords
            let keywordsPattern = "\\b(class|struct|enum|func|var|let|if|else|guard|return|for|in|while|switch|case|break|continue|default|import|typealias|protocol|extension|self|Self|true|false|nil|try|catch|throw|throws|async|await|mutating|public|private|internal|fileprivate|static|override|init)\\b"
            if let regex = try? NSRegularExpression(pattern: keywordsPattern) {
                regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                    if let mRange = match?.range {
                        attributed.addAttribute(.foregroundColor, value: keywordColor, range: mRange)
                        attributed.addAttribute(.font, value: boldFont, range: mRange)
                    }
                }
            }

            // Regex 2: Standard Types & User Class/Struct Types
            let typesPattern = "\\b(Int|Double|Float|String|Bool|Character|Array|Dictionary|Set|Void|Any|Object|Solution|TestCase|URL|URLSession|JSONDecoder|Codable)\\b"
            if let regex = try? NSRegularExpression(pattern: typesPattern) {
                regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                    if let mRange = match?.range {
                        attributed.addAttribute(.foregroundColor, value: typeColor, range: mRange)
                        attributed.addAttribute(.font, value: boldFont, range: mRange)
                    }
                }
            }

            // Regex 3: Function Declarations / Calls
            let funcPattern = "\\b([a-zA-Z_][a-zA-Z0-9_]*)(?=\\s*\\()"
            if let regex = try? NSRegularExpression(pattern: funcPattern) {
                regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                    if let mRange = match?.range {
                        // Skip keywords that might match func call pattern
                        let matchedStr = (text as NSString).substring(with: mRange)
                        if !["if", "for", "while", "guard", "switch", "catch"].contains(matchedStr) {
                            attributed.addAttribute(.foregroundColor, value: funcColor, range: mRange)
                        }
                    }
                }
            }

            // Regex 4: Numbers
            let numberPattern = "\\b\\d+(\\.\\d+)?\\b"
            if let regex = try? NSRegularExpression(pattern: numberPattern) {
                regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                    if let mRange = match?.range {
                        attributed.addAttribute(.foregroundColor, value: numberColor, range: mRange)
                    }
                }
            }

            // Regex 5: Strings
            let stringPattern = "\".*?\""
            if let regex = try? NSRegularExpression(pattern: stringPattern) {
                regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                    if let mRange = match?.range {
                        attributed.addAttribute(.foregroundColor, value: stringColor, range: mRange)
                    }
                }
            }

            // Regex 6: Single-line & Multi-line Comments (Highest precedence)
            let commentPattern = "//.*$|/\\*[\\s\\S]*?\\*/"
            if let regex = try? NSRegularExpression(pattern: commentPattern, options: [.anchorsMatchLines]) {
                regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                    if let mRange = match?.range {
                        attributed.addAttribute(.foregroundColor, value: commentColor, range: mRange)
                    }
                }
            }

            textView.textStorage?.setAttributedString(attributed)
        }
    }
}
#endif


