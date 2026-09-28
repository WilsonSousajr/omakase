import Foundation

/// The "Remind me" menu (M3.6 spec §2): three presets, a picked time, or
/// clear. Each is an instant counted from `now` in the user's calendar.
///
///     ReminderChoice.tomorrowMorning.date(from: .now, calendar: .current)   // tomorrow 09:00
public enum ReminderChoice: Equatable, Sendable {
    case inAnHour
    case thisEvening
    case tomorrowMorning
    case picked(Date)
    case clear

    /// The presets on offer at `now`: "this evening" only before 18:00.
    public static func presets(now: Date, calendar: Calendar) -> [ReminderChoice] {
        let evening = thisEvening.date(from: now, calendar: calendar) ?? now
        return evening > now ? [.inAnHour, .thisEvening, .tomorrowMorning] : [.inAnHour, .tomorrowMorning]
    }

    /// When to remind, or nil to clear the reminder.
    public func date(from now: Date, calendar: Calendar) -> Date? {
        switch self {
        case .inAnHour: return now + 3600
        case .thisEvening: return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now)
        case .tomorrowMorning:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)
        case .picked(let date): return date
        case .clear: return nil
        }
    }

    public var title: String {
        switch self {
        case .inAnHour: "In 1 hour"
        case .thisEvening: "This evening (18:00)"
        case .tomorrowMorning: "Tomorrow morning (09:00)"
        case .picked: "Pick a time…"
        case .clear: "Clear"
        }
    }
}
