import CoreGraphics

/// The shape family's measures (glass-pass §1, #283): every capsule control
/// (`.primary`, `.secondary`, their menus) is `height` tall and every `.icon`
/// circle `height` across, so no two controls side by side differ.
///
///     Circle().frame(width: ControlMetrics.markDot, height: ControlMetrics.markDot)
public enum ControlMetrics {
    /// The primary pill's own height before #283: a headline line (16 pt)
    /// and `Spacing.small` above and below. `ButtonStyleTests` pins it.
    public static let height: CGFloat = 32
    /// The kind dot on a chosen chip: colour as a mark, never a fill.
    public static let markDot: CGFloat = 6
    /// How much ink a chosen chip or an on toggle lays over its glass.
    public static let selectedFillOpacity = 0.12
    /// A pressed control's label.
    public static let pressedOpacity = 0.8
    /// A disabled control's label.
    public static let disabledOpacity = 0.5

    /// A glass control's label opacity: dimmed while pressed, more while disabled.
    ///
    ///     label.opacity(ControlMetrics.labelOpacity(isPressed: true, isEnabled: true))   // 0.8
    public static func labelOpacity(isPressed: Bool, isEnabled: Bool) -> Double {
        guard isEnabled else { return disabledOpacity }
        return isPressed ? pressedOpacity : 1
    }
}
