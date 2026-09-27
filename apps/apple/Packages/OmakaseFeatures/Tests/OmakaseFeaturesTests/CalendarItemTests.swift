import Foundation
import OmakaseAPI
import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// A study block for the marks and symbols builders (#263): `StudyBlockRecord`
/// has no plain initializer, so this decodes the same JSON the server sends.
@MainActor
private func studyBlock(id: String, disciplineID: String, title: String = "Study") throws -> StudyBlockRecord {
    let json = """
        {"id": "\(id)", "discipline": "\(disciplineID)", "title": "\(title)", "priority": "medium",
         "status": "scheduled", "estimated_minutes": null, "scheduled_date": "2026-09-27", "is_completed": false}
        """
    return StudyBlockRecord(dto: try OmakaseJSON.decoder.decode(StudyBlockDTO.self, from: Data(json.utf8)))
}

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

    /// A block knows its parent task, so its panel can open it (#217).
    @Test func aBlockCarriesItsParentTask() {
        let item = CalendarItem.block(
            id: "b1", day: "d", startTime: "09:00:00", endTime: "10:00:00", title: "Essay", taskID: "t1")
        #expect(item?.taskID == "t1")
        #expect(CalendarItem.block(id: "b", day: "d", startTime: "09:00", endTime: "10:00", title: "T")?.taskID == nil)
    }

    @Test func anItemsTimeRangeIsItsClockTimes() {
        let item = CalendarItem(id: "b", day: "d", start: 9 * 60 + 5, end: 14 * 60 + 30, title: "T", kind: .block)
        #expect(item.timeRange == "09:05 – 14:30")
    }

    @Test func aBlockAtLeastFortyFiveMinutesShowsItsTimeRangeIssue263() {
        let tall = CalendarItem(id: "b", day: "d", start: 0, end: 45, title: "T", kind: .block)
        let short = CalendarItem(id: "s", day: "d", start: 0, end: 44, title: "T", kind: .block)
        #expect(tall.showsTimeRange)
        #expect(!short.showsTimeRange)
    }

    @Test func aClassNeverShowsATimeRangeIssue263() {
        let item = CalendarItem(id: "c", day: "d", start: 0, end: 90, title: "T", kind: .classOccurrence)
        #expect(!item.showsTimeRange)
    }

    /// A block wears the colour and glyph `marks`/`symbols` give its parent
    /// task, keyed by the task's id (spec §9).
    @Test @MainActor func aTaskBlockTakesItsMarksColourAndSymbolIssue263() throws {
        let task = TaskRecord(id: "t1", title: "Essay", filing: TaskFiling(area: .life, parent: nil))
        let marks = ["t1": DesignColor(both: 0x4F46E5)]
        let symbols = CalendarItem.symbols(tasks: [task], studies: [])
        let record = TimeBlockRecord(id: "b1", day: "d", startTime: "09:00:00", endTime: "10:00:00", taskID: "t1")
        let item = try #require(CalendarItem.block(record, titles: [:], marks: marks, symbols: symbols))
        #expect(item.color == DesignColor(both: 0x4F46E5))
        #expect(item.symbol == "leaf")
    }

    /// A study block wears its discipline's colour and Study's glyph, keyed
    /// by the study block's id, not a task's (spec §9).
    @Test @MainActor func aStudyBlockTakesItsDisciplinesColourAndStudysSymbolIssue263() throws {
        let study = try studyBlock(
            id: "11111111-1111-1111-1111-111111111111", disciplineID: "22222222-2222-2222-2222-222222222222")
        let marks = [study.id: DesignColor(both: 0x111111)]
        let symbols = CalendarItem.symbols(tasks: [], studies: [study])
        let record = TimeBlockRecord(
            id: "b2", day: "d", startTime: "09:00:00", endTime: "10:00:00", studyBlockID: study.id)
        let item = try #require(CalendarItem.block(record, titles: [:], marks: marks, symbols: symbols))
        #expect(item.color == DesignColor(both: 0x111111))
        #expect(item.symbol == "graduationcap")
    }

    /// A parent the store hasn't cached leaves the block accent grey and
    /// without a glyph, same as before this slice (spec §9).
    @Test @MainActor func aBlockWhoseTaskIsNotInTheLookupFallsBackToAccentIssue263() throws {
        let record = TimeBlockRecord(id: "b3", day: "d", startTime: "09:00:00", endTime: "10:00:00", taskID: "gone")
        let item = try #require(CalendarItem.block(record, titles: [:], marks: [:], symbols: [:]))
        #expect(item.color == Palette.accent)
        #expect(item.symbol == nil)
    }

    /// The marks builder resolves a task through the directory, a study
    /// block through its discipline, and an unknown parent to the kind's
    /// own token (spec §9).
    @Test @MainActor func marksBuilderResolvesTaskStudyAndUnknownParentIssue263() throws {
        let task = TaskRecord(id: "t1", title: "Essay", filing: TaskFiling(area: .work, parent: .project("p1")))
        let study = try studyBlock(
            id: "33333333-3333-3333-3333-333333333333", disciplineID: "44444444-4444-4444-4444-444444444444")
        let project = PlaceEntry(
            parent: .project("p1"), title: "Thesis", group: nil, color: DesignColor(both: 0xABCDEF))
        let directory = PlaceDirectory(
            projects: [project],
            disciplines: [
                PlaceEntry(
                    parent: .discipline(study.disciplineID), title: "Calculus", group: nil,
                    color: DesignColor(both: 0x123456))
            ], semesterTitle: "Fall")
        let unknownTask = TaskRecord(id: "t2", title: "Rest", filing: TaskFiling(area: .life, parent: nil))
        let marks = CalendarItem.marks(tasks: [task, unknownTask], studies: [study], directory: directory)
        #expect(marks["t1"] == DesignColor(both: 0xABCDEF))
        #expect(marks[study.id] == DesignColor(both: 0x123456))
        #expect(marks["t2"] == KindTint.life)
    }

    /// The symbols builder gives a task its own kind's glyph and a study
    /// block Study's, regardless of which discipline it is under (spec §9).
    @Test @MainActor func symbolsBuilderGivesEachKindItsOwnGlyphIssue263() throws {
        let work = TaskRecord(id: "t1", title: "Essay", filing: TaskFiling(area: .work, parent: nil))
        let life = TaskRecord(id: "t2", title: "Rest", filing: TaskFiling(area: .life, parent: nil))
        let study = try studyBlock(
            id: "55555555-5555-5555-5555-555555555555", disciplineID: "66666666-6666-6666-6666-666666666666")
        let symbols = CalendarItem.symbols(tasks: [work, life], studies: [study])
        #expect(symbols["t1"] == "briefcase")
        #expect(symbols["t2"] == "leaf")
        #expect(symbols[study.id] == "graduationcap")
    }
}
