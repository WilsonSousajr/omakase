import OmakaseStore

/// A task's kind colour (spec §2): verdigris for Work, wisteria for Study,
/// dusty rose for Life. Chosen from the cool, muted range because shu,
/// matcha and indigo already mean focus and the timer's two breaks
/// ("Why these hues").
///
///     Circle().fill(KindTint.token(for: task.filing.area).color)
public enum KindTint {
    /// Verdigris.
    public static let work = DesignColor(dark: 0x3FA7A0, light: 0x1E7F78)
    /// Wisteria.
    public static let study = DesignColor(dark: 0xA48BD0, light: 0x6E58A6)
    /// Dusty rose.
    public static let life = DesignColor(dark: 0xC98AA0, light: 0x9E5874)

    /// The kind's own colour, with no parent involved.
    public static func token(for area: TaskArea) -> DesignColor {
        switch area {
        case .work: work
        case .study: study
        case .life: life
        }
    }

    /// The colour a task or block shows (spec §2): the parent's own colour
    /// when it reaches 3:1 on `Palette.background` in both appearances,
    /// otherwise the kind's token.
    public static func mark(for area: TaskArea, parentHex: String?) -> DesignColor {
        guard let parentHex, let color = DesignColor(hex: parentHex), isLegible(color) else {
            return token(for: area)
        }
        return color
    }

    private static func isLegible(_ color: DesignColor) -> Bool {
        RGB.contrast(color.dark, Palette.background.dark) >= 3
            && RGB.contrast(color.light, Palette.background.light) >= 3
    }
}
