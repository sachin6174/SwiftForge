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

// MARK: - Tab Accent Palette
//
// Single source of truth for the per-practice-tab color identity (the
// orange/red = DSA, blue/cyan = Swift Practice, purple/pink = MCQ, mint/teal
// = Machine Round, yellow/indigo = QA, pink/purple = Projects system used
// throughout the app's chrome). This used to be re-declared as near-identical
// switch statements in ContentView (x3), SidebarView (x3), DSASolutionView,
// and UIUtils' SidebarButton — kept in sync by hand, which had already
// drifted once (Swift Practice used a richer custom blue→cyan gradient in
// some spots and plain system .blue/.cyan in others). Every value below is
// the richest pre-existing definition found across those call sites, so
// centralizing this changes zero colors on screen — it only removes the
// duplication and fixes that one drift.
public struct TabAccent {
    public let primary: Color
    public let secondary: Color
    public let icon: String

    public init(primary: Color, secondary: Color, icon: String) {
        self.primary = primary
        self.secondary = secondary
        self.icon = icon
    }

    public var gradient: LinearGradient {
        LinearGradient(colors: [primary, secondary], startPoint: .leading, endPoint: .trailing)
    }

    public var verticalGradient: LinearGradient {
        LinearGradient(colors: [primary, secondary], startPoint: .top, endPoint: .bottom)
    }

    /// Soft stroke pair used for outlined chips/pickers (bright edge fading
    /// to a barely-there edge), matching SidebarView's mode-picker border.
    public var strokeGradientColors: [Color] {
        [primary.opacity(0.4), primary.opacity(0.1)]
    }
}

public enum TabAccents {
    public static let dsa = TabAccent(primary: .orange, secondary: .red, icon: "square.grid.3x3.fill")
    public static let swiftPractice = TabAccent(
        primary: Color(red: 0.1, green: 0.6, blue: 1.0),
        secondary: Color(red: 0.0, green: 0.85, blue: 0.9),
        icon: "network"
    )
    public static let mcq = TabAccent(primary: .purple, secondary: .pink, icon: "questionmark.circle.fill")
    public static let machineRound = TabAccent(primary: .mint, secondary: .teal, icon: "gearshape.fill")
    public static let qa = TabAccent(primary: .yellow, secondary: .indigo, icon: "books.vertical.fill")
    public static let projects = TabAccent(primary: .pink, secondary: .purple, icon: "hammer.fill")

    /// Keyed by the informal lowercase category string SidebarView's
    /// row/section helpers already pass around internally (`Question
    /// .category` values, plus "mcq"/"qa"/"projects") — a separate,
    /// pre-existing taxonomy from `PracticeTab.rawValue`, which holds
    /// display strings like "DSA Practice". Both entry points below resolve
    /// to the exact same palette.
    public static func forCategory(_ category: String) -> TabAccent {
        // Fully qualified (not `.swiftPractice` shorthand): this function's
        // return type is `TabAccent` (the plain struct), so bare dot-syntax
        // here would resolve against `TabAccent`'s own static members —
        // which don't exist — instead of `TabAccents` (this enum).
        switch category {
        case "swiftPractice": return TabAccents.swiftPractice
        case "mcq": return TabAccents.mcq
        case "machineRound": return TabAccents.machineRound
        case "qa": return TabAccents.qa
        case "projects": return TabAccents.projects
        default: return TabAccents.dsa
        }
    }
}

public extension PracticeTab {
    /// The canonical accent identity for this tab — see `TabAccents`.
    var accent: TabAccent {
        switch self {
        case .dsa: return TabAccents.dsa
        case .swiftPractice: return TabAccents.swiftPractice
        case .mcq: return TabAccents.mcq
        case .machineRound: return TabAccents.machineRound
        case .qa: return TabAccents.qa
        case .projects: return TabAccents.projects
        }
    }
}

// MARK: - Surfaces
//
// The app's existing elevation bands, named so new code can reach for
// "raised toolbar" instead of re-typing `Color(red: 0.1, green: 0.11, blue:
// 0.14)`. Values match what's already painted on screen today.
public enum Surface {
    /// Deepest layer — editor background, sidebar background.
    public static let canvas = Color(red: 0.05, green: 0.06, blue: 0.08)
    /// Main content panels (description/solution/console panes, workspace fill).
    public static let base = Color(red: 0.08, green: 0.09, blue: 0.12)
    /// Toolbars, header bars, command strips — one step brighter than `base`.
    public static let raised = Color(red: 0.10, green: 0.11, blue: 0.14)
    /// Popovers, menus, elevated cards that need to read above `raised` chrome.
    public static let overlay = Color(red: 0.13, green: 0.14, blue: 0.17)
    /// Recessed wells — code blocks, inset text containers.
    public static let well = Color(red: 0.04, green: 0.05, blue: 0.07)
}

// MARK: - Typography
//
// A small named scale over the sizes/weights already tuned throughout the
// app, so new text reaches for `ForgeFont.title()` instead of guessing at a
// system size. Existing `.font(.system(size:...))` call sites are left as-is.
public enum ForgeFont {
    public static func display(_ size: CGFloat = 20) -> Font { .system(size: size, weight: .black, design: .rounded) }
    public static func title(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    public static func label(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    public static func body(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .regular, design: .rounded) }
    public static func mono(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .monospaced) }
    public static func eyebrow(_ size: CGFloat = 9) -> Font { .system(size: size, weight: .black) }
}

public extension View {
    /// All-caps section kicker style ("PROBLEM DESCRIPTION", "DSA
    /// CHALLENGES", "SWIFT REFERENCE CODE", …). Deliberately does NOT chain
    /// `.tracking()` here — `Text` has its own always-available
    /// `tracking(_:) -> Text` overload, but once a `Text` is wrapped in a
    /// generic `View`-returning modifier like this one, `.tracking()` can
    /// only resolve to the newer, environment-based `View.tracking(_:)`
    /// (macOS 13/iOS 16+), which errors below that deployment target. Call
    /// `.tracking(0.8)` on the `Text` BEFORE `.eyebrowStyle()` (while it's
    /// still concretely typed as `Text`), not after.
    func eyebrowStyle(_ color: Color = Color.white.opacity(0.35)) -> some View {
        self.font(ForgeFont.eyebrow())
            .foregroundColor(color)
    }
}

// MARK: - Elevation & Canvas Helpers

public extension View {
    /// Soft ambient depth shadow for raised panels/cards.
    func forgeElevation(radius: CGFloat = 10, y: CGFloat = 5) -> some View {
        self.shadow(color: Color.black.opacity(0.35), radius: radius, x: 0, y: y)
    }

    /// Base surface fill plus an optional soft top-anchored accent-tinted
    /// glow wash — the pattern SidebarView already hand-rolls for its own
    /// background, centralized so any panel can share the same per-tab
    /// atmosphere. A single `ZStack`-backed `.background()` call, so it's
    /// safe to chain after other modifiers without the layering surprises
    /// that stacking multiple separate `.background()` calls can cause.
    func forgeCanvas(_ base: Color = Surface.canvas, glow: Color? = nil, glowIntensity: Double = 0.06) -> some View {
        self.background(
            ZStack {
                base
                if let glow {
                    LinearGradient(
                        colors: [glow.opacity(glowIntensity), Color.clear],
                        startPoint: .top, endPoint: .center
                    )
                }
            }
        )
    }
}

// MARK: - Reusable Empty State
//
/// Consistent "nothing to show here" treatment — a soft glowing icon badge
/// plus title/subtitle — replacing the ~6 bare "icon + one line of gray
/// text" placeholders that had each been written slightly differently
/// (different icon sizes, different opacities, some with no subtitle at all).
public struct ForgeEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String?
    let accent: Color

    public init(icon: String, title: String, subtitle: String? = nil, accent: Color = .white) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
    }

    public var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.08))
                    .frame(width: 72, height: 72)
                Circle()
                    .stroke(accent.opacity(0.18), lineWidth: 1)
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(accent.opacity(0.6))
                    .shadow(color: accent.opacity(0.25), radius: 8)
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.7))

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
