import CoreGraphics

/// The sidebar's measures (spec §6, #260): its column; the glyph column
/// the places' dots, the sub-headers and the now strip's ring take, in
/// line with the system's glyphs on the day's rows; and the ring itself.
///
///     List { … }.navigationSplitViewColumnWidth(
///         min: SidebarMetrics.minWidth, ideal: SidebarMetrics.idealWidth, max: SidebarMetrics.maxWidth)
public enum SidebarMetrics {
    /// Wide enough for the footer's account beside "Synced" and a place's
    /// name beside its count.
    public static let minWidth: CGFloat = 220
    public static let idealWidth: CGFloat = 260
    public static let maxWidth: CGFloat = 320
    /// The width a row's glyph takes: the now strip's ring and a place's dot
    /// sit in it, so every title starts on one line, as Finder's tags do.
    public static let iconColumn: CGFloat = 20
    /// The now strip's ring: a mark beside the countdown, not a dial.
    public static let ringDiameter: CGFloat = 16
    public static let ringLineWidth: CGFloat = 3
    /// A paused phase's strip, dimmed as a disabled control is.
    public static let pausedOpacity = ControlMetrics.disabledOpacity
}
