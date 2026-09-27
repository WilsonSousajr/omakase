import Foundation
import OmakaseStore

/// The cached classes and focus sessions (#200) as grid items (#203). Both are
/// read-only: a class is fixed by the timetable, and a session is what ran.
extension CalendarItem {
    /// Only focus is drawn; breaks are not planned work (M4 spec, Decisions).
    static let focusSessionType = "focus"

    /// A class in its discipline's colour, or accent grey when that colour
    /// isn't "#RRGGBB"; nil when its times don't parse or don't run forwards.
    @MainActor
    public static func classOccurrence(_ record: ClassOccurrenceRecord) -> CalendarItem? {
        guard let start = minutes(fromClock: record.startTime), let end = minutes(fromClock: record.endTime),
            end > start
        else { return nil }
        return CalendarItem(
            id: record.id, day: record.day, start: start, end: end, title: record.disciplineName,
            kind: .classOccurrence, tint: DesignColor(hex: record.disciplineColor))
    }

    /// A focus session at its real times in `calendar`'s zone. One still
    /// open ends after its duration; one crossing midnight is clipped to the
    /// day it started on.
    @MainActor
    public static func focusSession(_ record: SessionRecord, calendar: Calendar) -> CalendarItem? {
        guard record.sessionType == focusSessionType else { return nil }
        let ended = record.endedAt ?? record.startedAt.addingTimeInterval(TimeInterval(record.durationMinutes * 60))
        let start = minuteOfDay(record.startedAt, calendar: calendar)
        let end = calendar.isDate(ended, inSameDayAs: record.startedAt) ? minuteOfDay(ended, calendar: calendar) : 1440
        guard end > start else { return nil }
        return CalendarItem(
            id: record.id, day: DayString.format(record.startedAt, calendar: calendar), start: start, end: end,
            title: "Focus", kind: .focusSession)
    }

    /// The wall-clock minute of `date` in `calendar`'s zone.
    static func minuteOfDay(_ date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
