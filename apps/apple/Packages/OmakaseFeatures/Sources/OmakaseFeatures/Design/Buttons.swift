import SwiftUI

/// The one primary action on a screen (Sign in, Start): an inverted ink pill,
/// monochrome like the web client's. Every other button is neutral `.glass`.
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
            .background(Self.fill.color, in: .capsule)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    public static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
