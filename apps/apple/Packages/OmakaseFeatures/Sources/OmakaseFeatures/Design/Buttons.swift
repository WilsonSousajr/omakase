import SwiftUI

/// The one primary action on a screen (Sign in, Start): an inverted ink pill,
/// monochrome like the web client's. Every other button is a `.secondary`
/// glass capsule of the same height, `ControlMetrics.height` (#283).
/// Shu is a signal (the focus timer, the now line), never a button colour.
///
///     Button("Sign in with Google") { … }.buttonStyle(.primary)
public struct PrimaryButtonStyle: ButtonStyle {
    static let fill = Palette.ink
    static let label = Palette.background

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TypeScale.headline)
            .foregroundStyle(Self.label.color)
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.small)
            .frame(minHeight: ControlMetrics.height)
            .background(Self.fill.color, in: .capsule)
            .opacity(configuration.isPressed ? ControlMetrics.pressedOpacity : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    public static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

/// Every button but the one primary (Edit…, Reschedule ⌄, Today): a neutral
/// glass capsule as tall as the primary, its label ink (glass-pass §1, #283).
/// A chosen chip or an on toggle adds a faint ink fill; any colour it has is
/// a mark inside the label, never the capsule's.
///
///     Button("Edit…") { … }.buttonStyle(.secondary)
///     Button("Study") { … }.buttonStyle(SecondaryButtonStyle(isSelected: true))
public struct SecondaryButtonStyle: ButtonStyle {
    /// Ink, never dimmed: a grey label on glass read as disabled though it worked (#172, #213).
    static let label = Palette.ink
    /// A chosen capsule's fill, laid over the glass at `ControlMetrics.selectedFillOpacity`.
    static let selectedFill = Palette.ink
    private let isSelected: Bool

    public init(isSelected: Bool = false) { self.isSelected = isSelected }

    /// Ink, or `Palette.destructive` for a destructive button: mono chrome
    /// is about kind colour, not the platform's destructive signal (#283).
    ///
    ///     SecondaryButtonStyle.labelColor(for: .destructive)   // Palette.destructive
    static func labelColor(for role: ButtonRole?) -> DesignColor {
        role == .destructive ? Palette.destructive : label
    }

    public func makeBody(configuration: Configuration) -> some View {
        SecondaryCapsuleBody(
            label: configuration.label, role: configuration.role, isPressed: configuration.isPressed,
            isSelected: isSelected)
    }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    public static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// An icon-only button (‹ ›, the rating dots): a glass circle
/// `ControlMetrics.height` across, showing only the label's icon (#283).
///
///     Button("Next", systemImage: "chevron.right") { … }.buttonStyle(.icon)
public struct IconButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        IconCircleBody(label: configuration.label, role: configuration.role, isPressed: configuration.isPressed)
    }
}

extension ButtonStyle where Self == IconButtonStyle {
    public static var icon: IconButtonStyle { IconButtonStyle() }
}

/// A toggle drawn as a secondary capsule, chosen while on (the Calendar
/// overlay's switch). A button style never sees a toggle's state, so the
/// system's `.button` toggle style under `.secondary` would lose it.
///
///     Toggle(isOn: $isOn) { Label("Calendar", systemImage: "calendar") }.toggleStyle(.secondary)
public struct SecondaryToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
        }
        .buttonStyle(SecondaryButtonStyle(isSelected: configuration.isOn))
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

extension ToggleStyle where Self == SecondaryToggleStyle {
    public static var secondary: SecondaryToggleStyle { SecondaryToggleStyle() }
}

/// A menu button (Reschedule ⌄, Remind me ⌄, Repeat ⌄): a secondary capsule
/// with the ⌄ that says it opens a menu. Under `.menuStyle(.button)` macOS
/// draws a custom button style but drops its own indicator, and
/// `.menuIndicator(.visible)` does not bring it back (seen in a harness,
/// #283), so this style draws it.
///
///     Menu { … } label: { Text("Reschedule") }.menuStyle(.secondary)
public struct SecondaryMenuStyle: MenuStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Menu(configuration)
            .menuStyle(.button)
            .buttonStyle(SecondaryMenuButtonStyle())
    }
}

extension MenuStyle where Self == SecondaryMenuStyle {
    public static var secondary: SecondaryMenuStyle { SecondaryMenuStyle() }
}

/// The capsule `SecondaryMenuStyle` draws: the label, then the ⌄.
struct SecondaryMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let label = HStack(spacing: Spacing.tiny) {
            configuration.label
            // Drawn, not the system's indicator, so VoiceOver would read it
            // as "Down"; the menu button's own trait already says it opens.
            Image(systemName: "chevron.down").font(TypeScale.caption.weight(.semibold)).imageScale(.small)
                .accessibilityHidden(true)
        }
        return SecondaryCapsuleBody(label: label, role: nil, isPressed: configuration.isPressed, isSelected: false)
    }
}

/// The secondary capsule, a view so it can read whether it is enabled.
private struct SecondaryCapsuleBody<Label: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    let label: Label
    let role: ButtonRole?
    let isPressed: Bool
    let isSelected: Bool

    var body: some View {
        label
            .glassControlLabel(role: role, isPressed: isPressed, isEnabled: isEnabled)
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.small)
            .frame(minHeight: ControlMetrics.height)
            .background(isSelected ? chosenFill : .clear, in: .capsule)
            .contentShape(.capsule)
            .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var chosenFill: Color {
        SecondaryButtonStyle.selectedFill.color.opacity(ControlMetrics.selectedFillOpacity)
    }
}

/// The icon circle, a view so it can read whether it is enabled.
private struct IconCircleBody<Label: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    let label: Label
    let role: ButtonRole?
    let isPressed: Bool

    var body: some View {
        label
            .labelStyle(.iconOnly)
            .glassControlLabel(role: role, isPressed: isPressed, isEnabled: isEnabled)
            .frame(width: ControlMetrics.height, height: ControlMetrics.height)
            .contentShape(.circle)
            .glassEffect(.regular.interactive(), in: .circle)
    }
}

extension View {
    /// A glass control's label: the body face at medium weight, in ink (red
    /// for a destructive role), dimmed while pressed or disabled.
    fileprivate func glassControlLabel(role: ButtonRole?, isPressed: Bool, isEnabled: Bool) -> some View {
        font(TypeScale.body.weight(.medium))
            .foregroundStyle(SecondaryButtonStyle.labelColor(for: role).color)
            .opacity(ControlMetrics.labelOpacity(isPressed: isPressed, isEnabled: isEnabled))
    }
}
