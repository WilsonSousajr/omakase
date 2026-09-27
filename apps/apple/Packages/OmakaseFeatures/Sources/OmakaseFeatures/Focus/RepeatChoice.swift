import Foundation
import OmakaseStore

/// The "Repeat" menu (#206): four rules counted from the task's day, and
/// Stop repeating for a task already in a series. Weekdays are 0 (Monday)
/// to 6, as the server counts them.
///
///     RepeatChoice.choices(for: "2026-03-04", isRepeating: false, calendar: .current)
///     // [.daily, .weekdays, .weekly(weekday: 2), .monthly(day: 4)]
public enum RepeatChoice: Hashable, Sendable {
    case daily
    case weekdays
    case weekly(weekday: Int)
    case monthly(day: Int)
    case stop

    /// The choices on offer for a task on `day`; a day that does not parse
    /// has no weekday or day of the month to repeat on.
    public static func choices(for day: String, isRepeating: Bool, calendar: Calendar) -> [RepeatChoice] {
        var choices: [RepeatChoice] = [.daily, .weekdays]
        if let date = DayString.date(day, calendar: calendar) {
            let weekday = (calendar.component(.weekday, from: date) + 5) % 7
            choices += [.weekly(weekday: weekday), .monthly(day: calendar.component(.day, from: date))]
        }
        return isRepeating ? choices + [.stop] : choices
    }

    /// The rule starting on `day`, or nil for Stop repeating.
    public func rule(startsOn day: String) -> RepeatRule? {
        switch self {
        case .daily: RepeatRule(freq: .daily, startsOn: day)
        case .weekdays: RepeatRule(freq: .weekly, weekdays: [0, 1, 2, 3, 4], startsOn: day)
        case .weekly(let weekday): RepeatRule(freq: .weekly, weekdays: [weekday], startsOn: day)
        case .monthly: RepeatRule(freq: .monthly, startsOn: day)
        case .stop: nil
        }
    }

    public func title(calendar: Calendar) -> String {
        switch self {
        case .daily: "Daily"
        case .weekdays: "Weekdays (Mon–Fri)"
        case .weekly(let weekday): "Weekly on \(calendar.weekdaySymbols[(weekday + 1) % 7])"
        case .monthly(let day): "Monthly on day \(day)"
        case .stop: "Stop repeating"
        }
    }
}
