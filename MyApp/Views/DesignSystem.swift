import SwiftUI

// MARK: - Design Tokens
//
// Central spacing/radius/motion constants so new UI reaches for a shared
// vocabulary instead of one-off magic numbers. Existing views keep their
// already-tuned inline values (rewriting every hardcoded number across the
// app for a token system would be a large, risky diff for no visible
// benefit) — these are for new work and for the shared components below.

public enum Spacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 28
}

public enum Radius {
    public static let sm: CGFloat = 6
    public static let md: CGFloat = 8
    public static let lg: CGFloat = 12
    public static let xl: CGFloat = 16
}

public extension Animation {
    /// Quick, tactile feedback for taps/presses.
    static var snappy: Animation { .spring(response: 0.28, dampingFraction: 0.62) }
    /// Gentle settle for panel/section/value transitions.
    static var smooth: Animation { .spring(response: 0.45, dampingFraction: 0.85) }
    /// Playful overshoot reserved for celebratory moments — used sparingly.
    static var bouncy: Animation { .spring(response: 0.5, dampingFraction: 0.55) }
}

// MARK: - Pressable Button Style
//
/// Drop-in replacement for `PlainButtonStyle()` that adds a satisfying
/// press-down scale without touching the label's own visual design — every
/// existing button keeps its exact look, it just gains tactile feedback.
public struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat

    public init(scale: CGFloat = 0.96) {
        self.scale = scale
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.snappy, value: configuration.isPressed)
    }
}

// MARK: - Pulse On Change
//
/// Gives a value a quick, bouncy "pop" whenever it changes — used for things
/// like the streak counter or solved count so progress feels like it landed,
/// not just silently updated.
public struct PulseOnChange<Value: Equatable>: ViewModifier {
    let value: Value
    @State private var pulse = false

    public func body(content: Content) -> some View {
        content
            .scaleEffect(pulse ? 1.16 : 1.0)
            .onChange(of: value) { _ in
                withAnimation(.bouncy) { pulse = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.smooth) { pulse = false }
                }
            }
    }
}

public extension View {
    func pulseOnChange<Value: Equatable>(_ value: Value) -> some View {
        modifier(PulseOnChange(value: value))
    }
}
