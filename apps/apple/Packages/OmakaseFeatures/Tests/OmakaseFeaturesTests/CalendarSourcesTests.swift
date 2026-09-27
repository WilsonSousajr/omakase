import Foundation
import OmakaseAPI
import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// The cached classes and focus sessions as grid items (#203): a class in its
/// discipline's colour, a session at its real local times, clipped to the day
/// it started on.
@MainActor
struct CalendarSourcesTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }()

    func occurrence(
        color: String = "#4F46E5", start: String = "08:00:00", end: String = "09:30:00", cancelled: Bool = false
    ) throws -> ClassOccurrenceRecord {
        let json = """
            {"id": "c1-2026-09-28", "class_schedule_id": "8C1C3F8E-2B7B-4C39-9E6A-3C5D8F1B2A40",
             "discipline_name": "Linear algebra", "discipline_color": "\(color)", "class_type": "lecture",
             "location": "B12", "date": "2026-09-28", "start_time": "\(start)", "end_time": "\(end)",
             "week": 1, "is_cancelled": \(cancelled)}
            """
        let dto = try OmakaseJSON.decoder.decode(ClassOccurrenceDTO.self, from: Data(json.utf8))
        return ClassOccurrenceRecord(dto: dto)
    }

    func session(type: String = "focus", started: String, ended: String?, minutes: Int = 25) throws -> SessionRecord {
        let endedAt = ended.map { "\"\($0)\"" } ?? "null"
        let json = """
            {"id": "5A0B7C2E-9D41-4F3A-8B6C-1E2D3F4A5B6C", "task": null, "time_block": null,
             "session_type": "\(type)", "duration_minutes": \(minutes), "started_at": "\(started)",
             "ended_at": \(endedAt), "completed": true}
            """
        return SessionRecord(dto: try OmakaseJSON.decoder.decode(PomodoroSessionDTO.self, from: Data(json.utf8)))
    }

    @Test func aHexColourIsReadWithOrWithoutItsHash() {
        #expect(DesignColor(hex: "#4F46E5") == DesignColor(both: 0x4F46E5))
        #expect(DesignColor(hex: "4f46e5") == DesignColor(both: 0x4F46E5))
    }

    @Test func aColourThatIsNotSixHexDigitsIsNil() {
        #expect(DesignColor(hex: "") == nil)
        #expect(DesignColor(hex: "#FFF") == nil)
        #expect(DesignColor(hex: "indigo") == nil)
        #expect(DesignColor(hex: "#4F46E5AA") == nil)
    }

    @Test func aClassIsDrawnInItsDisciplinesColour() throws {
        let item = CalendarItem.classOccurrence(try occurrence())
        #expect(
            item
                == CalendarItem(
                    id: "c1-2026-09-28", day: "2026-09-28", start: 480, end: 570, title: "Linear algebra",
                    kind: .classOccurrence, tint: DesignColor(both: 0x4F46E5), symbol: "book"))
    }

    /// A class keeps its own glyph and dashed outline (spec §9): it is
    /// fixed by the timetable, not a kind a task or study block wears.
    @Test func aClassOccurrenceKeepsBookAndDashedIssue263() throws {
        let item = try #require(CalendarItem.classOccurrence(try occurrence()))
        #expect(item.symbol == "book")
        #expect(item.kind == .classOccurrence)
    }

    @Test func aCancelledClassIsACancelledItemIssue207() throws {
        let item = try #require(CalendarItem.classOccurrence(try occurrence(cancelled: true)))
        #expect(item.isCancelled && item.kind == .classOccurrence)
        #expect(CalendarItem.classOccurrence(try occurrence())?.isCancelled == false)
    }

    @Test func aClassWithAnUnreadableColourIsAccentGrey() throws {
        let item = try #require(CalendarItem.classOccurrence(try occurrence(color: "blue")))
        #expect(item.tint == nil)
        #expect(item.color == Palette.accent)
    }

    @Test func aClassWhoseTimesDoNotParseIsDropped() throws {
        #expect(CalendarItem.classOccurrence(try occurrence(start: "8am")) == nil)
        #expect(CalendarItem.classOccurrence(try occurrence(start: "10:00:00", end: "09:00:00")) == nil)
    }

    @Test func aFocusSessionIsDrawnAtItsLocalTimes() throws {
        let record = try session(started: "2026-09-28T12:05:00Z", ended: "2026-09-28T12:30:00Z")
        let item = CalendarItem.focusSession(record, calendar: calendar)
        #expect(
            item
                == CalendarItem(
                    id: "5A0B7C2E-9D41-4F3A-8B6C-1E2D3F4A5B6C", day: "2026-09-28", start: 545, end: 570,
                    title: "Focus", kind: .focusSession))
    }

    @Test func aSessionWithoutAnEndRunsForItsDuration() throws {
        let record = try session(started: "2026-09-28T12:05:00Z", ended: nil, minutes: 50)
        let item = try #require(CalendarItem.focusSession(record, calendar: calendar))
        #expect((item.start, item.end) == (545, 595))
    }

    @Test func aSessionCrossingMidnightIsClippedToItsStartDay() throws {
        // 23:40 to 00:10 the next day, in São Paulo (UTC-3).
        let record = try session(started: "2026-09-29T02:40:00Z", ended: "2026-09-29T03:10:00Z")
        let item = try #require(CalendarItem.focusSession(record, calendar: calendar))
        #expect((item.day, item.start, item.end) == ("2026-09-28", 1420, 1440))
    }

    @Test func breaksAreNotDrawn() throws {
        let record = try session(type: "short_break", started: "2026-09-28T12:05:00Z", ended: "2026-09-28T12:10:00Z")
        #expect(CalendarItem.focusSession(record, calendar: calendar) == nil)
    }

    @Test func aSessionThatRanNoTimeIsNotDrawn() throws {
        let record = try session(started: "2026-09-28T12:05:00Z", ended: nil, minutes: 0)
        #expect(CalendarItem.focusSession(record, calendar: calendar) == nil)
    }
}
