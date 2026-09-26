import Testing

@testable import OmakaseFeatures

/// What the Plan grid draws, as values: the server's "HH:MM:SS" read as
/// minutes since midnight, and a block titled by its parent (#202).
struct CalendarItemTests {
    @Test func aClockTimeIsMinutesSinceMidnight() {
        #expect(CalendarItem.minutes(fromClock: "00:00:00") == 0)
        #expect(CalendarItem.minutes(fromClock: "09:30:00") == 570)
        #expect(CalendarItem.minutes(fromClock: "23:59:59") == 1439)
        #expect(CalendarItem.minutes(fromClock: "14:45") == 885)
    }

    @Test func aMalformedClockTimeIsRejected() {
        #expect(CalendarItem.minutes(fromClock: "") == nil)
        #expect(CalendarItem.minutes(fromClock: "9:30") == nil)
        #expect(CalendarItem.minutes(fromClock: "24:00:00") == nil)
        #expect(CalendarItem.minutes(fromClock: "12:60:00") == nil)
        #expect(CalendarItem.minutes(fromClock: "ab:cd:ef") == nil)
    }

    @Test func aBlockCarriesItsDayTimesAndTitle() {
        let item = CalendarItem.block(
            id: "b1", day: "2026-09-26", startTime: "09:00:00", endTime: "10:30:00", title: "Write the essay")
        #expect(
            item
                == CalendarItem(
                    id: "b1", day: "2026-09-26", start: 540, end: 630, title: "Write the essay", kind: .block))
    }

    @Test func aBlockWhoseTimesDoNotParseOrRunBackwardsIsDropped() {
        #expect(CalendarItem.block(id: "b", day: "d", startTime: "x", endTime: "10:00:00", title: "T") == nil)
        #expect(CalendarItem.block(id: "b", day: "d", startTime: "10:00:00", endTime: "10:00:00", title: "T") == nil)
    }

    @Test func aBlockIsTitledByItsParentOrCalledATimeBlock() {
        let titles = ["t1": "Write the essay", "s1": "Read chapter 3"]
        #expect(CalendarItem.blockTitle(taskID: "t1", studyBlockID: nil, titles: titles) == "Write the essay")
        #expect(CalendarItem.blockTitle(taskID: nil, studyBlockID: "s1", titles: titles) == "Read chapter 3")
        #expect(CalendarItem.blockTitle(taskID: "gone", studyBlockID: nil, titles: titles) == "Time block")
        #expect(CalendarItem.blockTitle(taskID: nil, studyBlockID: nil, titles: titles) == "Time block")
    }

    @Test func anItemWithoutASourceColourIsAccentGrey() {
        let plain = CalendarItem(id: "b", day: "d", start: 0, end: 60, title: "T", kind: .block)
        let tinted = CalendarItem(
            id: "c", day: "d", start: 0, end: 60, title: "C", kind: .classOccurrence, tint: Palette.indigo)
        #expect(plain.color == Palette.accent)
        #expect(tinted.color == Palette.indigo)
    }
}
