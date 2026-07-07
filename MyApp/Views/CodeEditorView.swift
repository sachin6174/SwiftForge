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
    #if os(macOS)
    @State private var scrollOffsetY: CGFloat = 0
    #endif

    public init(code: Binding<String>, fileName: String, isFocused: Bool = false, onToggleFocus: (() -> Void)? = nil) {
        self._code = code
        self.fileName = fileName
        self.isFocused = isFocused
        self.onToggleFocus = onToggleFocus
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // ── Header Bar ──
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .shadow(color: .orange.opacity(0.4), radius: 3)
                    
                    Text(fileName)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    // Saved Indicator Badge
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 4, height: 4)
                        Text("Autosaved")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
                    
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
                .background(Color(red: 0.1, green: 0.11, blue: 0.14))
                
                Spacer()
                
                if let onToggleFocus = onToggleFocus {
                    Button(action: onToggleFocus) {
                        HStack(spacing: 4) {
                            Image(systemName: isFocused ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 9, weight: .bold))
                            Text(isFocused ? "Exit Full Screen" : "Full Screen Editor")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(isFocused ? .orange : Color.white.opacity(0.65))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                        .background(isFocused ? Color.orange.opacity(0.12) : Color.white.opacity(0.04))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isFocused ? Color.orange.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 0.75)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(red: 0.1, green: 0.11, blue: 0.14))
            
            Divider()
                .background(Color.white.opacity(0.06))

            // Syntax Highlighting Editor & Line Numbers Gutter
            HStack(alignment: .top, spacing: 0) {
                #if os(macOS)
                LineNumberGutterView(text: code, scrollOffsetY: scrollOffsetY)
                MacCodeEditor(text: $code, scrollOffsetY: $scrollOffsetY)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                #else
                IOSCodeEditor(text: $code)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                #endif
            }
            .frame(maxHeight: .infinity)
        }
        .background(Color(red: 0.05, green: 0.06, blue: 0.08))
    }
}

#if os(macOS)
// MARK: - SwiftUI Line Number Gutter
//
// A previous AppKit NSRulerView-based gutter (attached via
// NSScrollView.verticalRulerView) turned out to break SwiftUI's compositor for
// this entire window on the current beta SDK: mixing that ruler's legacy
// drawRect-style drawing into the view tree left sibling SwiftUI views
// (sidebar, header, description pane) permanently uncomposited, even after
// forcing layer-backing on the ruler/scrollView/textView. Rendering line
// numbers in plain SwiftUI instead, synced to AppKit's scroll position via
// NSView.boundsDidChangeNotification, avoids that interop landmine entirely.
struct LineNumberGutterView: View {
    let text: String
    let scrollOffsetY: CGFloat

    private static let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    private static let lineHeight: CGFloat = ceil(font.ascender - font.descender + font.leading)
    private static let topInset: CGFloat = 8

    private var lineCount: Int {
        text.isEmpty ? 1 : text.components(separatedBy: "\n").count
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(1...max(1, lineCount), id: \.self) { i in
                Text("\(i)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .frame(height: Self.lineHeight)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, Self.topInset)
        .padding(.trailing, 6)
        .offset(y: -scrollOffsetY)
        .frame(width: 40)
        .background(Color(red: 0.05, green: 0.05, blue: 0.07))
        .clipped()
    }
}

// MARK: - Mac NSTextView Representable with Syntax Highlighting & Line Numbers
struct MacCodeEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var scrollOffsetY: CGFloat

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

        // CRITICAL: Use a non-zero initial frame to prevent NSLayoutManager from
        // caching a zero-width state during SwiftUI's initial layout pass.
        // When contentSize is (0,0), the text container calculates a negative/zero
        // width which causes the entire text view to collapse to invisible.
        let contentSize = scrollView.contentSize
        let initialSize = NSSize(
            width: max(contentSize.width, 600),
            height: max(contentSize.height, 400)
        )
        let textView = NSTextView(frame: NSRect(origin: .zero, size: initialSize))
        textView.minSize = NSSize(width: 0, height: initialSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        textView.textContainer?.containerSize = NSSize(width: initialSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        textView.backgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
        textView.textColor = NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.insertionPointColor = NSColor.orange
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 8, height: 8)

        textView.delegate = context.coordinator

        scrollView.documentView = textView

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.boundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        let initialText = text
        DispatchQueue.main.async {
            context.coordinator.applyHighlighting(to: textView, text: initialText)
        }

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

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func boundsDidChange(_ notification: Notification) {
            guard let clipView = notification.object as? NSClipView else { return }
            parent.scrollOffsetY = clipView.bounds.origin.y
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



#if os(iOS)
// MARK: - iOS UITextView Representable with Syntax Highlighting & Line Numbers
struct IOSCodeEditor: UIViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
        textView.textColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        textView.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.tintColor = .systemOrange
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.isScrollEnabled = true
        textView.delegate = context.coordinator

        context.coordinator.applyHighlighting(to: textView, text: text)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            let selectedRange = uiView.selectedRange
            context.coordinator.applyHighlighting(to: uiView, text: text)
            uiView.selectedRange = selectedRange
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: IOSCodeEditor
        var isUpdating = false

        init(_ parent: IOSCodeEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdating else { return }
            let newText = textView.text ?? ""
            parent.text = newText
            
            let selectedRange = textView.selectedRange
            applyHighlighting(to: textView, text: newText)
            textView.selectedRange = selectedRange
        }

        func applyHighlighting(to textView: UITextView, text: String) {
            isUpdating = true
            defer { isUpdating = false }

            let font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            let boldFont = UIFont.monospacedSystemFont(ofSize: 13, weight: .bold)

            // Theme Colors (LeetCode Dark Palette - Identical to macOS)
            let defaultColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)      // Off-white
            let keywordColor = UIColor(red: 0.33, green: 0.61, blue: 0.94, alpha: 1.0)      // LeetCode Cyan/Blue (#569CD6)
            let typeColor = UIColor(red: 0.30, green: 0.78, blue: 0.69, alpha: 1.0)         // LeetCode Emerald Teal (#4EC9B0)
            let stringColor = UIColor(red: 0.80, green: 0.56, blue: 0.47, alpha: 1.0)       // Warm Amber/Orange (#CE9178)
            let numberColor = UIColor(red: 0.70, green: 0.80, blue: 0.65, alpha: 1.0)       // Lime Green (#B5CEA8)
            let commentColor = UIColor(red: 0.41, green: 0.60, blue: 0.33, alpha: 1.0)      // Muted Green/Gray (#6A9955)
            let funcColor = UIColor(red: 0.86, green: 0.86, blue: 0.66, alpha: 1.0)         // Soft Gold (#DCDCAA)

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

            textView.attributedText = attributed
        }
    }
}
#endif
