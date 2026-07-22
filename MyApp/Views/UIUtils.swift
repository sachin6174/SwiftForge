import SwiftUI

// MARK: - Glassmorphic Card View Modifier
public struct GlassCard: ViewModifier {
    public func body(content: Content) -> some View {
        content
            // Material + a subtle diagonal sheen combined into ONE
            // background call (a ZStack, not two chained `.background()`
            // modifiers) — chaining would put the sheen BEHIND the material
            // instead of layered on top of it, since each `.background()`
            // nests further back than the last.
            .background(
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.clear, Color.black.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            )
            // Layered shadow (soft wide ambient + tight contact shadow) reads
            // as a genuinely floating card instead of a flat drop-shadow.
            .shadow(color: Color.black.opacity(0.4), radius: 18, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.22), radius: 3, x: 0, y: 1)
    }
}

extension View {
    public func glassCard() -> some View {
        self.modifier(GlassCard())
    }
}

// MARK: - Reusable UI Components

/// Collapsible header for a topic section within the sidebar's question list
/// (e.g. "Sliding Window", "Networking & APIs"). Tapping toggles `isExpanded`.
public struct SidebarSectionHeader: View {
    let title: String
    let solvedCount: Int
    let totalCount: Int
    let accentColor: Color
    @Binding var isExpanded: Bool

    public init(title: String, solvedCount: Int, totalCount: Int, accentColor: Color, isExpanded: Binding<Bool>) {
        self.title = title
        self.solvedCount = solvedCount
        self.totalCount = totalCount
        self.accentColor = accentColor
        self._isExpanded = isExpanded
    }

    public var body: some View {
        Button(action: {
            withAnimation(.smooth) {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(isExpanded ? accentColor.opacity(0.7) : Color.white.opacity(0.3))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 10)

                Text(title.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(Color.white.opacity(0.45))
                    .tracking(0.8)
                    .lineLimit(1)
                    .layoutPriority(1)

                Spacer(minLength: 4)

                Text("\(solvedCount)/\(totalCount)")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(solvedCount == totalCount ? Color.green.opacity(0.85) : Color.white.opacity(0.3))
                    .pulseOnChange(solvedCount)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.97))
    }
}

public struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let isSolved: Bool
    let activeTab: String
    let previewText: String?
    @Binding var isPreviewExpanded: Bool
    let action: () -> Void

    @State private var isPressed = false
    @State private var isHovered = false

    public init(
        title: String,
        icon: String,
        isSelected: Bool,
        isSolved: Bool = false,
        activeTab: String = "dsa",
        previewText: String? = nil,
        isPreviewExpanded: Binding<Bool> = .constant(false),
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.isSolved = isSolved
        self.activeTab = activeTab
        self.previewText = previewText
        self._isPreviewExpanded = isPreviewExpanded
        self.action = action
    }

    /// Single source of truth for this row's accent color across every tab —
    /// used both directly (accent bar, icon-off state) and to build
    /// `accentGradient` below, so mcq/machineRound rows no longer silently
    /// fall through to the DSA orange default the way they did before this
    /// was centralized (there was no "mcq" or "machineRound" case anywhere
    /// in this file; every ternary here only ever checked "swiftPractice").
    private var accentSolidColor: Color {
        TabAccents.forCategory(activeTab).primary
    }

    private var accentSecondaryColor: Color {
        TabAccents.forCategory(activeTab).secondary
    }

    private var accentGradient: LinearGradient {
        LinearGradient(colors: [accentSolidColor, accentSecondaryColor], startPoint: .top, endPoint: .bottom)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                Button(action: action) {
                    HStack(spacing: 10) {
                        // Glowing left accent indicator
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isSelected ? accentGradient : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
                            .frame(width: 3, height: 18)
                            .shadow(color: isSelected ? accentSolidColor.opacity(0.8) : Color.clear, radius: 4)

                        Image(systemName: icon)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(
                                isSelected
                                    ? accentGradient
                                    : LinearGradient(colors: [Color.white.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                            )
                            .frame(width: 16)

                        Text(title)
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : Color.white.opacity(0.6))
                            .lineLimit(1)
                            .help(title)

                        Spacer()

                        if isSolved {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                                .shadow(color: Color.green.opacity(0.8), radius: 3)
                                .padding(.trailing, 4)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background(
                        Group {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                accentSolidColor.opacity(0.15),
                                                accentSecondaryColor.opacity(0.05)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(accentSolidColor.opacity(0.25), lineWidth: 0.5)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(isHovered ? 0.04 : (isPressed ? 0.02 : 0.0)))
                            }
                        }
                    )
                    .scaleEffect(isPressed ? 0.98 : 1.0)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { over in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isHovered = over
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in withAnimation(.easeOut(duration: 0.08)) { isPressed = true } }
                        .onEnded { _ in withAnimation(.easeOut(duration: 0.12)) { isPressed = false } }
                )
                .accessibilityLabel("\(title)\(isSolved ? ", solved" : "")")

                // Separate disclosure button (a sibling, not nested inside
                // the row's own Button above) so tapping it toggles the
                // inline preview WITHOUT also triggering `action` (opening
                // the question) — a chevron nested inside another Button's
                // label can't reliably receive its own distinct tap.
                if previewText != nil {
                    Button(action: {
                        withAnimation(.smooth) { isPreviewExpanded.toggle() }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color.white.opacity(isPreviewExpanded ? 0.6 : 0.3))
                            .rotationEffect(.degrees(isPreviewExpanded ? 90 : 0))
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(isPreviewExpanded ? "Hide preview" : "Show preview")
                }
            }

            if isPreviewExpanded, let previewText, !previewText.isEmpty {
                Text(previewText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 37)
                    .padding(.trailing, 10)
                    .padding(.top, 2)
                    .padding(.bottom, 6)
            }
        }
    }
}

public struct ConstraintBullet: View {
    let text: String
    let accent: Color

    public init(text: String, accent: Color = .orange) {
        self.text = text
        self.accent = accent
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundColor(accent)
                .shadow(color: accent.opacity(0.5), radius: 3)
                .padding(.top, 6)
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
        }
    }
}

public struct FieldRow: View {
    let name: String
    let type: String
    let value: String
    
    public init(name: String, type: String, value: String) {
        self.name = name
        self.type = type
        self.value = value
    }
    
    public var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
            Text(":")
                .foregroundColor(.white.opacity(0.3))
                .font(.system(size: 10))
            Text(type)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.cyan.opacity(0.8))
            Spacer()
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.orange)
                .bold()
        }
    }
}

public struct LineConnector: View {
    let isActive: Bool
    let isForward: Bool
    
    @State private var offset: CGFloat = 0.0
    
    public init(isActive: Bool, isForward: Bool) {
        self.isActive = isActive
        self.isForward = isForward
    }
    
    public var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 2)
            
            if isActive {
                Circle()
                    .fill(isForward ? Color.orange : Color.cyan)
                    .frame(width: 5, height: 5)
                    .shadow(color: isForward ? Color.orange : Color.cyan, radius: 3)
                    .offset(x: offset)
                    .onAppear {
                        offset = isForward ? -15.0 : 15.0
                        withAnimation(Animation.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                            offset = isForward ? 15.0 : -15.0
                        }
                    }
                    .onDisappear {
                        offset = 0.0
                    }
            }
        }
        .frame(width: 30, height: 20)
    }
}

public struct DSARunButton: View {
    let isRunning: Bool
    let action: () -> Void

    @State private var isHovered = false

    public init(isRunning: Bool, action: @escaping () -> Void) {
        self.isRunning = isRunning
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isRunning {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(isRunning ? "Executing..." : "Run Suite")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: isRunning
                                ? [Color.gray.opacity(0.4), Color.gray.opacity(0.3)]
                                : [Color(red: 0.15, green: 0.75, blue: 0.45), Color(red: 0.0, green: 0.65, blue: 0.55)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(isRunning ? 0.0 : 0.18), lineWidth: 0.75)
                            .blendMode(.overlay)
                    )
            )
            .shadow(color: isRunning ? Color.clear : Color.green.opacity(isHovered ? 0.5 : 0.28), radius: isHovered ? 10 : 6, x: 0, y: 3)
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .disabled(isRunning)
        .buttonStyle(PlainButtonStyle())
        .onHover { over in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = over
            }
        }
        .keyboardShortcut("r", modifiers: [.command])
    }
}

// MARK: - Cross-Platform Syntax Highlighting Engine

#if os(macOS)
import AppKit
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
#else
import UIKit
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
#endif

public enum SyntaxHighlightingEngine {
    public static func highlight(code: String) -> AttributedString {
        var attributed = AttributedString(code)
        let baseFont = PlatformFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let baseColor = PlatformColor(red: 0.88, green: 0.92, blue: 0.96, alpha: 1.0)
        
        attributed.font = baseFont
        attributed.foregroundColor = Color(baseColor)
        
        let nsString = code as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        
        // 1. Comments (Muted Silver Blue)
        applyRegex(pattern: "//.*$|/\\*[\\s\\S]*?\\*/", options: [.anchorsMatchLines], code: code, fullRange: fullRange, attributed: &attributed, color: PlatformColor(red: 0.45, green: 0.52, blue: 0.62, alpha: 1.0))
        
        // 2. String Literals (Editor Light Green #98C379)
        applyRegex(pattern: "\".*?\"", options: [], code: code, fullRange: fullRange, attributed: &attributed, color: PlatformColor(red: 0.55, green: 0.78, blue: 0.42, alpha: 1.0))
        
        // 3. Swift Keywords (Editor Magenta/Pink #D15A98)
        let keywords = ["func", "let", "var", "class", "struct", "enum", "import", "return", "if", "else", "for", "in", "while", "guard", "switch", "case", "default", "try", "await", "async", "public", "private", "override", "mutating", "self", "super", "nil", "true", "false"]
        let keywordPattern = "\\b(" + keywords.joined(separator: "|") + ")\\b"
        applyRegex(pattern: keywordPattern, options: [], code: code, fullRange: fullRange, attributed: &attributed, color: PlatformColor(red: 0.88, green: 0.38, blue: 0.57, alpha: 1.0))
        
        // 4. Swift Standard Types (Editor Cyan #56B6C2)
        let types = ["Int", "String", "Bool", "Double", "Float", "Character", "Array", "Dictionary", "Set", "ListNode", "Solution", "TestCase", "URLSession", "URL", "JSONDecoder", "Data", "Date", "Error"]
        let typePattern = "\\b(" + types.joined(separator: "|") + ")\\b"
        applyRegex(pattern: typePattern, options: [], code: code, fullRange: fullRange, attributed: &attributed, color: PlatformColor(red: 0.30, green: 0.75, blue: 0.85, alpha: 1.0))
        
        // 5. Numbers (Editor Orange/Gold #D19A66)
        applyRegex(pattern: "\\b\\d+(\\.\\d+)?\\b", options: [], code: code, fullRange: fullRange, attributed: &attributed, color: PlatformColor(red: 0.86, green: 0.58, blue: 0.36, alpha: 1.0))
        
        // 6. Swift Attributes (Editor Purple #C678DD)
        applyRegex(pattern: "@[A-Za-z0-9_]+", options: [], code: code, fullRange: fullRange, attributed: &attributed, color: PlatformColor(red: 0.75, green: 0.45, blue: 0.90, alpha: 1.0))
        
        return attributed
    }
    
    private static func applyRegex(
        pattern: String,
        options: NSRegularExpression.Options,
        code: String,
        fullRange: NSRange,
        attributed: inout AttributedString,
        color: PlatformColor
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let matches = regex.matches(in: code, options: [], range: fullRange)
        
        for match in matches {
            guard let swiftRange = Range(match.range, in: code),
                  let attrRange = Range(swiftRange, in: attributed) else { continue }
            attributed[attrRange].foregroundColor = Color(color)
        }
    }
}
