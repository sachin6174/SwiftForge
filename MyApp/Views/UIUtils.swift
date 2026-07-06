import SwiftUI

// MARK: - Reusable UI Components

public struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    public init(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Glowing left accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected
                        ? LinearGradient(colors: [Color.orange, Color.red], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 3, height: 18)
                    .shadow(color: isSelected ? Color.orange.opacity(0.7) : Color.clear, radius: 4)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                            ? LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.gray.opacity(0.7), Color.gray.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 15)

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : Color(white: 0.55))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 6)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.13), Color.red.opacity(0.07)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(Color.orange.opacity(0.18), lineWidth: 0.5)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.white.opacity(isPressed ? 0.04 : 0.0))
                    }
                }
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeOut(duration: 0.1)) { isPressed = true } }
                .onEnded { _ in withAnimation(.easeOut(duration: 0.15)) { isPressed = false } }
        )
    }
}


public struct ConstraintBullet: View {
    let text: String
    
    public init(text: String) {
        self.text = text
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.orange)
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.65))
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
                .foregroundColor(.white.opacity(0.95))
            Text(":")
                .foregroundColor(.gray)
                .font(.system(size: 9))
            Text(type)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.blue.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.orange)
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
                .fill(Color.gray.opacity(0.12))
                .frame(height: 2)
            
            if isActive {
                Circle()
                    .fill(isForward ? Color.orange : Color.blue)
                    .frame(width: 4, height: 4)
                    .shadow(color: isForward ? Color.orange : Color.blue, radius: 2)
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

    public init(isRunning: Bool, action: @escaping () -> Void) {
        self.isRunning = isRunning
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isRunning {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(isRunning ? "Running..." : "Run Code")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.85), Color.teal.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: Color.green.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .disabled(isRunning)
        .buttonStyle(PlainButtonStyle())
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
        
        // 1. Comments (Slate Muted Gray)
        applyRegex(pattern: "//.*$|/\\*[\\s\\S]*?\\*/", options: [.anchorsMatchLines], code: code, fullRange: fullRange, attributed: &attributed, color: PlatformColor(red: 0.50, green: 0.52, blue: 0.56, alpha: 1.0))
        
        // 2. String Literals (LeetCode Light Green #98C379)
        applyRegex(pattern: "\".*?\"", options: [], code: code, fullRange: fullRange, attributed: &attributed, color: PlatformColor(red: 0.60, green: 0.76, blue: 0.47, alpha: 1.0))
        
        // 3. Swift Keywords (LeetCode Magenta/Pink #D15A98)
        let keywords = ["func", "let", "var", "class", "struct", "enum", "import", "return", "if", "else", "for", "in", "while", "guard", "switch", "case", "default", "try", "await", "async", "public", "private", "override", "mutating", "self", "super", "nil", "true", "false"]
        let keywordPattern = "\\b(" + keywords.joined(separator: "|") + ")\\b"
        applyRegex(pattern: keywordPattern, options: [], code: code, fullRange: fullRange, attributed: &attributed, color: PlatformColor(red: 0.82, green: 0.35, blue: 0.60, alpha: 1.0))
        
        // 4. Swift Standard Types (LeetCode Cyan #56B6C2)
        let types = ["Int", "String", "Bool", "Double", "Float", "Character", "Array", "Dictionary", "Set", "ListNode", "Solution", "TestCase", "URLSession", "URL", "JSONDecoder", "Data", "Date", "Error"]
        let typePattern = "\\b(" + types.joined(separator: "|") + ")\\b"
        applyRegex(pattern: typePattern, options: [], code: code, fullRange: fullRange, attributed: &attributed, color: PlatformColor(red: 0.34, green: 0.71, blue: 0.76, alpha: 1.0))
        
        // 5. Numbers (LeetCode Orange/Gold #D19A66)
        applyRegex(pattern: "\\b\\d+(\\.\\d+)?\\b", options: [], code: code, fullRange: fullRange, attributed: &attributed, color: PlatformColor(red: 0.82, green: 0.60, blue: 0.40, alpha: 1.0))
        
        // 6. Swift Attributes (LeetCode Purple #C678DD)
        applyRegex(pattern: "@[A-Za-z0-9_]+", options: [], code: code, fullRange: fullRange, attributed: &attributed, color: PlatformColor(red: 0.78, green: 0.47, blue: 0.87, alpha: 1.0))
        
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
