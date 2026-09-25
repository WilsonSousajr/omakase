/// Omakase's colours: sumi (ink and paper neutrals) and one accent, shu.
/// The contrast each pair must meet is pinned in `PaletteTests`; the reasons
/// are in docs/design-system-apple.md.
///
///     Rectangle().fill(Palette.background.color)
public enum Palette {
    /// Paper in light, sumi in dark: the opaque ground content sits on.
    public static let background = DesignColor(light: 0xF7F4EE, dark: 0x141312)
    public static let surface = DesignColor(light: 0xEFEBE3, dark: 0x1E1C1A)
    public static let ink = DesignColor(light: 0x1C1A17, dark: 0xEDE8DF)
    public static let inkMuted = DesignColor(light: 0x6F6A62, dark: 0x9A948A)
    public static let hairline = DesignColor(light: 0xDDD7CC, dark: 0x2E2B28)
    /// Vermilion: the accent, the focus phase, the prominent action.
    public static let shu = DesignColor(light: 0xC8402A, dark: 0xD0462C)
    /// Short break.
    public static let matcha = DesignColor(light: 0x5E8C61, dark: 0x7FAF82)
    /// Ai (indigo): long break.
    public static let indigo = DesignColor(light: 0x3F5E8C, dark: 0x6D8FC4)
}
