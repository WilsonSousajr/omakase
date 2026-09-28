import Foundation
import Testing

@testable import OmakaseFeatures

/// Calendar.app's events as grid items (#229): one item per day an event
/// touches, clipped to that day, at its local times; all-day events stay
/// off the grid.
struct CalendarExternalTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }()

    func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    func event(
        start: String, end: String, isAllDay: Bool = false, color: String? = "#34C759"
    ) -> ExternalEvent {
        ExternalEvent(
            id: "e1", title: "Dentist", start: date(start), end: date(end), isAllDay: isAllDay, calendarColor: color)
    }

    @Test func anEventWithinADayIsOneItemAtItsLocalTimes() {
        let items = CalendarItem.external(
            event(start: "2026-09-28T12:00:00Z", end: "2026-09-28T13:30:00Z"), calendar: calendar)
        #expect(
            items == [
                CalendarItem(
                    id: "e1@2026-09-28", day: "2026-09-28", start: 540, end: 630, title: "Dentist",
                    kind: .externalEvent, tint: DesignColor(both: 0x34C759))
            ])
    }

    @Test func anEventCrossingMidnightIsSplitIntoEachDay() {
        let items = CalendarItem.external(
            event(start: "2026-09-29T01:00:00Z", end: "2026-09-29T05:00:00Z"), calendar: calendar)
        #expect(items.map(\.day) == ["2026-09-28", "2026-09-29"])
        #expect(items.map(\.start) == [1320, 0])
        #expect(items.map(\.end) == [1440, 120])
        #expect(Set(items.map(\.id)).count == 2)
    }

    @Test func anEventSpanningDaysFillsTheDaysBetween() {
        let items = CalendarItem.external(
            event(start: "2026-09-28T21:00:00Z", end: "2026-09-30T12:00:00Z"), calendar: calendar)
        #expect(items.map(\.day) == ["2026-09-28", "2026-09-29", "2026-09-30"])
        #expect(items[1].start == 0)
        #expect(items[1].end == 1440)
    }

    @Test func anEventEndingAtMidnightDoesNotSpillIntoTheNextDay() {
        let items = CalendarItem.external(
            event(start: "2026-09-29T01:00:00Z", end: "2026-09-29T03:00:00Z"), calendar: calendar)
        #expect(items.map(\.day) == ["2026-09-28"])
        #expect(items.map(\.end) == [1440])
    }

    @Test func anAllDayEventIsLeftOffTheGrid() {
        let items = CalendarItem.external(
            event(start: "2026-09-28T03:00:00Z", end: "2026-09-29T03:00:00Z", isAllDay: true), calendar: calendar)
        #expect(items.isEmpty)
    }

    @Test func anEventThatDoesNotRunForwardsIsDropped() {
        let items = CalendarItem.external(
            event(start: "2026-09-28T13:00:00Z", end: "2026-09-28T13:00:00Z"), calendar: calendar)
        #expect(items.isEmpty)
    }

    @Test func anEventWithoutACalendarColourIsAccentGrey() {
        let items = CalendarItem.external(
            event(start: "2026-09-28T12:00:00Z", end: "2026-09-28T13:00:00Z", color: nil), calendar: calendar)
        #expect(items.first?.tint == nil)
        #expect(items.first?.color == Palette.accent)
    }

    @Test func externalEventsAreNeverLanedWithBlocks() {
        let external = CalendarItem(
            id: "x", day: "2026-09-28", start: 540, end: 600, title: "Meeting", kind: .externalEvent)
        let block = CalendarItem(id: "b", day: "2026-09-28", start: 540, end: 600, title: "Essay", kind: .block)
        #expect(CalendarLayout.lanes(for: [external, block])["x"] == nil)
        #expect(CalendarLayout.lanes(for: [external, block])["b"]?.count == 1)
    }
}
