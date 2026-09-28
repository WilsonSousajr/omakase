import SwiftUI

/// Named animation tokens (spec §2, §10). The only file allowed to call
/// `withAnimation(`/`.animation(` directly (the `raw_animation` SwiftLint
/// rule, from S2 on), so every screen respects Reduce Motion through here.
///
///     Circle().motion(Motion.select, value: isSelected)
public enum Motion {
    /// Chips, selection, toggles.
    public static let select: Animation = .snappy(duration: 0.22)
    /// Panels opening, List ⇄ Kanban, rows arriving.
    public static let layout: Animation = .smooth(duration: 0.35)
    /// A task being completed.
    public static let complete: Animation = .bouncy

    /// `animation`, or nil when Reduce Motion is on.
    public static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    /// A digit's content transition: `.numericText()`, or `.identity` under Reduce Motion.
    public static func digits(reduceMotion: Bool) -> ContentTransition {
        reduceMotion ? .identity : .numericText()
    }

    /// Runs `body` inside `withAnimation`, resolved for Reduce Motion, so
    /// screens never call `withAnimation` themselves.
    public static func perform(_ animation: Animation, reduceMotion: Bool, _ body: () -> Void) {
        withAnimation(resolved(animation, reduceMotion: reduceMotion), body)
    }
}

/// Applies a `Motion` token to `value`, reading Reduce Motion itself so
/// callers never branch on it.
private struct MotionModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {
        content.animation(Motion.resolved(animation, reduceMotion: reduceMotion), value: value)
    }
}

extension View {
    /// `animation`, applied to `value`, resolved for Reduce Motion (spec §2).
    public func motion<Value: Equatable>(_ animation: Animation, value: Value) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }
}
