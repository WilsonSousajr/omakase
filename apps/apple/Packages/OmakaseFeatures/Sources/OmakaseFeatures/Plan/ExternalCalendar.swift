import Foundation

/// An event from the user's own calendar (Calendar.app), as a value (#229).
/// Omakase only reads these; nothing is written back (parent spec L35).
///
///     ExternalEvent(id: "e1", title: "Dentist", start: start, end: end, isAllDay: false, calendarColor: "#34C759")
public struct ExternalEvent: Equatable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    /// The calendar's colour as "#RRGGBB", when it has one.
    public let calendarColor: String?

    public init(id: String, title: String, start: Date, end: Date, isAllDay: Bool, calendarColor: String?) {
        (self.id, self.title, self.start, self.end) = (id, title, start, end)
        (self.isAllDay, self.calendarColor) = (isAllDay, calendarColor)
    }
}

/// Whether the user let Omakase read their calendar.
public enum ExternalCalendarAccess: Equatable, Sendable {
    case notDetermined
    case granted
    case denied
}

/// The read-only calendar Plan draws behind its blocks. The app backs it
/// with EventKit; the package never imports EventKit, so tests use a fake.
@MainActor
public protocol ExternalCalendar: AnyObject {
    var access: ExternalCalendarAccess { get }
    /// Asks once (the system prompt); true when access is granted.
    func requestAccess() async -> Bool
    /// The events overlapping `start..<end`.
    func events(from start: Date, to end: Date) async -> [ExternalEvent]
}

extension CalendarItem {
    /// An external event as one item per day it touches, clipped to that
    /// day at `calendar`'s local times. All-day events are left off the
    /// grid for now: they have no times to place (#229).
    public static func external(_ event: ExternalEvent, calendar: Calendar) -> [CalendarItem] {
        guard !event.isAllDay, event.end > event.start else { return [] }
        var items: [CalendarItem] = []
        var dayStart = calendar.startOfDay(for: event.start)
        while dayStart < event.end, let next = calendar.date(byAdding: .day, value: 1, to: dayStart) {
            if let item = externalSlice(event, from: dayStart, to: next, calendar: calendar) { items.append(item) }
            dayStart = next
        }
        return items
    }

    /// The part of `event` inside one day; nil when nothing of it is left.
    private static func externalSlice(
        _ event: ExternalEvent, from dayStart: Date, to nextDay: Date, calendar: Calendar
    ) -> CalendarItem? {
        let start = minuteOfDay(max(event.start, dayStart), calendar: calendar)
        let end = event.end >= nextDay ? 1440 : minuteOfDay(event.end, calendar: calendar)
        guard end > start else { return nil }
        let day = DayString.format(dayStart, calendar: calendar)
        return CalendarItem(
            id: "\(event.id)@\(day)", day: day, start: start, end: end, title: event.title, kind: .externalEvent,
            tint: event.calendarColor.flatMap { DesignColor(hex: $0) })
    }
}
