import Foundation

/// Today in the user's calendar, as `YYYY-MM-DD`, read fresh on every access
/// so a window left open past midnight moves to the new day (M1's known
/// limitation). Features may not import OmakaseAPI, so it formats the day
/// itself, the same shape as `APIDay`.
///
///     FocusDay().today   // "2026-03-07"
public struct FocusDay: Sendable {
    private let clock: @Sendable () -> Date
    private let calendar: Calendar

    public init(clock: @escaping @Sendable () -> Date = { .now }, calendar: Calendar = .current) {
        (self.clock, self.calendar) = (clock, calendar)
    }

    public var today: String {
        let parts = calendar.dateComponents([.year, .month, .day], from: clock())
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
