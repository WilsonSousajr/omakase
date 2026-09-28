/// Omakase's colours: sumi (ink and paper neutrals), monochrome chrome, and
/// shu as the one signal colour.
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
    public static let inkMuted = DesignColor(dark: 0x9B958B, light: 0x69645C)
    public static let hairline = DesignColor(dark: 0x2E2B28, light: 0xDDD7CC)
    /// The system accent (checkboxes, selection): grey, so the chrome is
    /// fully monochrome, as the web client's was.
    public static let accent = DesignColor(dark: 0x77726A, light: 0x6F6A62)
    /// Vermilion: a signal only, the focus phase and the now line. Never a
    /// button or accent colour.
    public static let shu = DesignColor(dark: 0xD0462C, light: 0xC8402A)
    /// Short break.
    public static let matcha = DesignColor(dark: 0x7FAF82, light: 0x5E8C61)
    /// Ai (indigo): long break.
    public static let indigo = DesignColor(dark: 0x6D8FC4, light: 0x3F5E8C)
    /// A destructive button's label ("Delete block"): the platform's red
    /// signal, which mono chrome keeps (G1 review, #283). Never shu. Lighter
    /// (dark) and deeper (light) than the system red, which reads only 2.6 /
    /// 1.8:1 over the blurred ground the glass sits on; this reads 4.6:1.
    public static let destructive = DesignColor(dark: 0xFFA297, light: 0x8C201A)
}
