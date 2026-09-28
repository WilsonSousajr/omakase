import SwiftUI

/// Omakase is designed dark first; light is the alternative, not the base.
///
///     ContentView().preferredColorScheme(Appearance.default.colorScheme)
public enum Appearance: Sendable {
    case dark
    case light

    public static let `default` = Appearance.dark

    public var colorScheme: ColorScheme { self == .dark ? .dark : .light }
}

/// How much of the ground covers the desktop behind the window. The rest is
/// the system's blurred material. `TranslucencyTests` pins the text contrast
/// this leaves over the worst desktop.
public enum Translucency {
    public static let window = 0.5
}

extension View {
    /// The window's translucent ground: the blurred desktop behind, tinted
    /// with sumi (or paper). Content on it stays unfilled; cards use `surface`.
    public func omakaseWindowBackground() -> some View {
        // The material must be the window's own container background to blur
        // what is behind the window; a material filled inside the window only
        // blurs the window's content, which is why the ground was opaque (#170).
        background(Palette.background.color.opacity(Translucency.window).ignoresSafeArea())
            .containerBackground(.ultraThinMaterial, for: .window)
    }
}
