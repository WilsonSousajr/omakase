import CoreGraphics

/// Spacing on a 4-point grid.
///
///     VStack(spacing: Spacing.large) { … }.padding(Spacing.xxLarge)
public enum Spacing {
    public static let tiny: CGFloat = 4
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 16
    public static let xLarge: CGFloat = 24
    public static let xxLarge: CGFloat = 32
}

/// Corner radii: small for marks and fields, medium for rows, large for panels.
public enum Radius {
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 16
}

/// The main window's size bounds.
public enum WindowSize {
    /// M1's frame: the smallest window Today stays readable in.
    public static let minimum = CGSize(width: 520, height: 420)
}
