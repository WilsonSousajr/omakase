/// Omakase's colours: sumi (ink and paper neutrals) and one accent, shu.
/// The contrast each pair must meet is pinned in `PaletteTests`; the reasons
/// are in docs/design-system-apple.md.
///
///     Rectangle().fill(Palette.background.color)
public enum Palette {
    /// Sumi in dark, paper in light: the window's ground. It is laid over the
    /// desktop at `Translucency.window`; cards use `surface`, which is opaque.
    public static let background = DesignColor(dark: 0x141312, light: 0xF7F4EE)
    public static let surface = DesignColor(dark: 0x1E1C1A, light: 0xEFEBE3)
    public static let ink = DesignColor(dark: 0xEDE8DF, light: 0x1C1A17)
    public static let inkMuted = DesignColor(dark: 0x9A948A, light: 0x6F6A62)
    public static let hairline = DesignColor(dark: 0x2E2B28, light: 0xDDD7CC)
    /// Vermilion: the accent, the focus phase, the prominent action.
    public static let shu = DesignColor(dark: 0xD0462C, light: 0xC8402A)
    /// Short break.
    public static let matcha = DesignColor(dark: 0x7FAF82, light: 0x5E8C61)
    /// Ai (indigo): long break.
    public static let indigo = DesignColor(dark: 0x6D8FC4, light: 0x3F5E8C)
}
