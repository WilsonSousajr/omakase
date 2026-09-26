import SwiftUI

/// Omakase's named type styles over SF Pro text styles, so Dynamic Type
/// scales them.
///
///     Text("OMAKASE").font(TypeScale.display).tracking(TypeScale.displayTracking)
public enum TypeScale {
    /// The wordmark and the timer's remaining time.
    public static let display = Font.system(.largeTitle, weight: .light)
    public static let title = Font.system(.title2, weight: .semibold)
    public static let headline = Font.headline
    public static let body = Font.body
    public static let caption = Font.caption
    /// Carried over from the web record: small, semibold, uppercase, tracked.
    public static let sectionLabel = Font.system(.caption, weight: .semibold)

    public static let displayTracking: CGFloat = 6
    public static let sectionLabelTracking: CGFloat = 1.5
}

extension Text {
    /// The section label: `Text("Today").sectionLabel()`.
    public func sectionLabel() -> some View {
        font(TypeScale.sectionLabel)
            .tracking(TypeScale.sectionLabelTracking)
            .textCase(.uppercase)
            .foregroundStyle(Palette.inkMuted.color)
    }
}
