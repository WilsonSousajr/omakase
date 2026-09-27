/// The accent each place the app hosts SwiftUI applies: `Palette.accent`,
/// the monochrome grey, in every one (docs/design-system-apple.md).
///
/// macOS honours the app's `AccentColor` asset only while the user's system
/// accent is Multicolor. With any other chosen, whatever the app does not
/// tint itself takes the user's colour: the sidebar icons and the capture
/// panel's caret were purple on a Mac set to purple (#214).
///
///     MenuBarTimerPanelView(...).tint(AppTint.menuBarPanel.color)
public enum AppTint {
    /// The main window's `.tint`: controls, selection, text carets.
    public static let window = Palette.accent
    /// The sidebar's icons, through `.listItemTint(.fixed(_:))`: a sidebar
    /// takes its icons' colour from the system accent, not from `.tint`.
    public static let sidebarIcons = Palette.accent
    /// The menu bar's timer panel, a scene of its own that the window's
    /// `.tint` does not reach.
    public static let menuBarPanel = Palette.accent
    /// The capture panel, an `NSPanel` whose `NSHostingView` is its own root:
    /// its text caret.
    public static let capturePanel = Palette.accent
}
