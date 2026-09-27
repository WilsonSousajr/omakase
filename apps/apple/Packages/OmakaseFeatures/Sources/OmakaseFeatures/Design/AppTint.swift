/// The accent each place the app hosts SwiftUI applies; nil leaves the
/// system's, which is the user's own accent colour.
public enum AppTint {
    /// The main window's `.tint`.
    public static let window: DesignColor? = Palette.accent
    /// The sidebar's icons.
    public static let sidebarIcons: DesignColor? = nil
    /// The menu bar's timer panel.
    public static let menuBarPanel: DesignColor? = nil
    /// The capture panel (its text caret).
    public static let capturePanel: DesignColor? = nil
}
