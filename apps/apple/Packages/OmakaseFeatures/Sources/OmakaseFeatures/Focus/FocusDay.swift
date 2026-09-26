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

    public var today: String { DayString.format(clock(), calendar: calendar) }
}
