# Fix Record: Blank App Window (Sidebar/Header/Description Never Rendered)

## Symptom

On launch, the macOS app window showed almost nothing: an empty bordered box,
a bare line-number gutter (numbers only, no code text), and the bottom
console — but the sidebar, top header, question description pane, and the
code editor's own text were all missing. This reproduced on every launch
(via `open`, direct binary exec, after resizing the window, and after
waiting 90+ seconds), so it was not a timing race — a previous fix attempt
(deferring `scrollView.tile()` to the next run loop tick, plus a
`window.contentView?.needsDisplay = true` "safety net" in `ContentView`'s
`onAppear`) did not resolve it.

## Root cause

`MacCodeEditor` (the `NSViewRepresentable` wrapping the code editor's
`NSTextView`) attached a custom line-number gutter via
`NSScrollView.verticalRulerView`:

```swift
final class LineNumberRulerView: NSRulerView {
    init(scrollView: NSScrollView) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        self.clientView = scrollView.documentView
        self.ruleThickness = 40
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        NSColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0).set()
        rect.fill()

        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        let string = textView.string as NSString
        let textLen = string.length
        guard textLen > 0 else { return }

        let startCharLoc = min(characterRange.location, textLen)
        let endCharLoc = min(characterRange.location + characterRange.length, textLen)

        var lineNumber = 1
        if startCharLoc > 0 {
            string.enumerateSubstrings(in: NSRange(location: 0, length: startCharLoc), options: [.byLines, .substringNotRequired]) { _, _, _, _ in
                lineNumber += 1
            }
        }

        string.enumerateSubstrings(in: NSRange(location: startCharLoc, length: textLen - startCharLoc), options: [.byLines, .substringNotRequired]) { _, substringRange, _, stop in
            if substringRange.location >= endCharLoc {
                stop.pointee = true
                return
            }
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: substringRange.location)
            let lineRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let y = lineRect.origin.y + textView.textContainerOrigin.y - visibleRect.origin.y + 1

            let numStr = "\(lineNumber)" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor(white: 0.4, alpha: 1.0)
            ]
            let size = numStr.size(withAttributes: attrs)
            numStr.draw(at: NSPoint(x: self.ruleThickness - size.width - 6, y: y), withAttributes: attrs)
            lineNumber += 1
        }
    }
}
```

...wired up in `makeNSView`:

```swift
let rulerView = LineNumberRulerView(scrollView: scrollView)
scrollView.verticalRulerView = rulerView
scrollView.hasVerticalRuler = true
scrollView.rulersVisible = true

// tile() was already deferred to DispatchQueue.main.async by a prior fix
// attempt, and layer-backing (wantsLayer = true) was added to the ruler,
// scrollView, and textView. Neither change fixed the bug.
```

On the current beta SDK (Xcode-beta, `MacOSX27.0.sdk`), attaching this
`NSRulerView` — which draws via the legacy `drawHashMarksAndLabels`
override, i.e. immediate-mode drawing, not SwiftUI's Core Animation
compositor — permanently prevented the surrounding SwiftUI view tree
(sidebar, header, description pane, and even the `NSTextView`'s own text)
from ever compositing into the window. This was confirmed by isolation
testing:

1. Swapping `MacCodeEditor` for a plain SwiftUI `TextEditor` → everything
   rendered correctly immediately.
2. Restoring `MacCodeEditor` but commenting out only the ruler
   (`verticalRulerView`/`hasVerticalRuler`/`rulersVisible`) → sidebar,
   header, and description rendered correctly (code text lagged briefly,
   unrelated to the ruler).
3. Restoring the ruler with `wantsLayer = true` added to the ruler view,
   the scroll view, and the text view → bug came back immediately, and did
   **not** self-heal even after 90+ seconds of runtime (ruling out a
   timing race).

Conclusion: the AppKit `NSRulerView`-based gutter itself — not timing, not
layer-backing — is what broke the window's compositing.

## Fix

Removed the AppKit ruler entirely and replaced the line-number gutter with
a plain SwiftUI view, kept in sync with the `NSScrollView`'s scroll
position via `NSView.boundsDidChangeNotification` (instead of driving it
through AppKit's ruler mechanism):

```swift
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
```

`MacCodeEditor` gained a `scrollOffsetY` binding and now observes scroll
position directly instead of touching a ruler:

```swift
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

        // applyHighlighting(to:text:) unchanged — same regex-based syntax
        // highlighting as before.
    }
}
```

And `CodeEditorView` now places the new gutter next to the editor and owns
the shared scroll-offset state:

```swift
public struct CodeEditorView: View {
    @Binding var code: String
    let fileName: String
    let isFocused: Bool
    let onToggleFocus: (() -> Void)?
    #if os(macOS)
    @State private var scrollOffsetY: CGFloat = 0
    #endif

    ...

    public var body: some View {
        VStack(spacing: 0) {
            // ── Header Bar ── (unchanged)
            ...

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
```

## Verification

- Rebuilt Release (`xcodebuild ... -scheme SwiftForge -configuration Release`)
  and launched the app repeatedly (via `open`, direct binary exec, after
  a real window resize, after 90+ seconds idle, and after the display went
  to sleep and woke back up).
- Sidebar (logo, search, question list, progress), top header (tab
  picker, question title, Open Book / streak / solved badges), the
  description pane, and the code editor (with syntax highlighting and
  correctly positioned line numbers) all render immediately and
  consistently now — no more blank window.
- File touched: `MyApp/Views/CodeEditorView.swift` only.

## Note on scope

This repo currently has a large set of unrelated, already-in-progress
uncommitted UI changes (`ContentView.swift`, `SidebarView.swift`,
`DSADescriptionView.swift`, `DSASolutionView.swift`,
`DSATestCasesView.swift`, `UIUtils.swift`, `ConsoleView.swift`,
`DatabaseService.swift`, `run_app.sh`, the `.xcodeproj`, and the
entitlements file). None of those were touched for this fix — only
`MyApp/Views/CodeEditorView.swift` was changed. Two throwaway debug
markers added during isolation testing (`DEBUG-SIDEBAR-MARKER` in
`SidebarView.swift`, `DEBUG-HEADER-MARKER` in `ContentView.swift`) were
added and then removed again before this record was written; neither file
carries any net diff from this investigation.
