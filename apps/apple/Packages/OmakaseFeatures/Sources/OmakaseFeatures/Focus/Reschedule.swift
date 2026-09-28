import Foundation

/// Where a task can be moved (spec, Offline: tomorrow, a chosen date, or
/// none). Today is offered for carried-over tasks only.
///
///     RescheduleOption.tomorrow.day(from: "2026-03-07", calendar: .current)   // "2026-03-08"
public enum RescheduleOption: Equatable, Sendable {
    case today
    case tomorrow
    case date(Date)
    case backlog

    /// The `YYYY-MM-DD` to schedule on, or nil for the backlog (sent as an
    /// explicit null) and for a `today` that isn't a day.
    public func day(from today: String, calendar: Calendar) -> String? {
        switch self {
        case .today: return today
        case .backlog: return nil
        case .date(let date): return DayString.format(date, calendar: calendar)
        case .tomorrow:
            guard let start = DayString.date(today, calendar: calendar),
                let next = calendar.date(byAdding: .day, value: 1, to: start)
            else { return nil }
            return DayString.format(next, calendar: calendar)
        }
    }
}

/// `YYYY-MM-DD` to and from dates in one calendar. Features may not import
/// OmakaseAPI's `APIDay`, so the same shape is kept here.
public enum DayString {
    static func format(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Exactly `YYYY-MM-DD`, as the server's `parse_client_date` accepts; a
    /// same-length `DD-MM-YYYY` would otherwise read as year 7.
    static func date(_ day: String, calendar: Calendar) -> Date? {
        guard let match = day.wholeMatch(of: /(\d{4})-(\d{2})-(\d{2})/),
            let year = Int(match.1), let month = Int(match.2), let dayOfMonth = Int(match.3)
        else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth))
    }

    /// "14:30": the zero-padded 24-hour clock that block times compare against.
    public static func time(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// "Mon 2": the short weekday and the day of the month.
    static func short(_ day: String, calendar: Calendar) -> String? {
        guard let date = date(day, calendar: calendar) else { return nil }
        let weekday = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
        return "\(weekday) \(calendar.component(.day, from: date))"
    }
}
