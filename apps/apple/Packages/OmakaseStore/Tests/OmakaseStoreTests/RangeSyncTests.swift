import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// The visible week's blocks, classes and sessions (#200), in a UTC-3 calendar
/// so that the local days and the UTC instants differ.
@MainActor
struct RangeSyncTests {
    let container: ModelContainer
    let api = FakeAPIClient()
    let saoPaulo: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }()
    let week = (21...27).map { "2026-09-\($0)" }

    init() throws { container = try StoreSchema.container(inMemory: true) }

    func sync() -> RangeSync { RangeSync(api: api, context: container.mainContext, calendar: saoPaulo) }

    func blocks() throws -> [TimeBlockRecord] {
        try container.mainContext.fetch(FetchDescriptor<TimeBlockRecord>(sortBy: [SortDescriptor(\.day)]))
    }

    func classes() throws -> [ClassOccurrenceRecord] {
        try container.mainContext.fetch(FetchDescriptor<ClassOccurrenceRecord>(sortBy: [SortDescriptor(\.day)]))
    }

    func sessions() throws -> [SessionRecord] {
        try container.mainContext.fetch(FetchDescriptor<SessionRecord>(sortBy: [SortDescriptor(\.startedAt)]))
    }

    func queueWrite(for subjectID: String) {
        container.mainContext.insert(
            OutboxEntry(sequence: 1, method: "PATCH", path: "/api/v1/timeblocks/x/", body: nil, subjectID: subjectID))
    }

    @Test func theWeekIsAskedForByLocalDayAndByUTCInstant() async throws {
        try await sync().refresh(days: week)
        // Local midnight in UTC-3 is 03:00Z; the end is the start of the day after the last.
        #expect(
            Set(await api.requestedRanges) == [
                "blocks 2026-09-21..2026-09-27", "classes 2026-09-21..2026-09-27",
                "sessions 2026-09-21T03:00:00Z..2026-09-28T03:00:00Z",
            ])
    }

    @Test func anEmptyRangeReadsNothing() async throws {
        try await sync().refresh(days: [])
        #expect(await api.requestedRanges.isEmpty)
    }

    @Test func aStringThatIsNotADayIsRejectedWithTheValue() async throws {
        await #expect(throws: RangeDayError(raw: "21/09/2026")) { try await sync().refresh(days: ["21/09/2026"]) }
        #expect(RangeDayError(raw: "x").description == #"day "x" is not YYYY-MM-DD"#)
    }

    @Test func refreshStoresTheWeeksBlocksClassesAndSessions() async throws {
        let block = UUID()
        await api.setBlocks([try .make(id: block, day: "2026-09-22")], on: "2026-09-22")
        await api.setOccurrences([try .make(day: "2026-09-23")])
        await api.setSessions([try .make(startedAt: "2026-09-22T12:00:00Z", block: block)])
        try await sync().refresh(days: week)
        #expect(try blocks().map(\.day) == ["2026-09-22"])
        let occurrence = try #require(try classes().first)
        #expect(occurrence.day == "2026-09-23" && occurrence.disciplineName == "Calculus")
        #expect(occurrence.startTime == "08:00:00" && occurrence.endTime == "09:40:00")
        #expect(occurrence.classType == "lecture" && occurrence.location == "Room 101")
        #expect(occurrence.disciplineColor == "#3B82F6")
        let session = try #require(try sessions().first)
        #expect(session.timeBlockID == block.uuidString && session.taskID == nil && session.sessionType == "focus")
        #expect(session.durationMinutes == 25 && !session.completed && session.endedAt == nil)
    }

    @Test func aSecondRefreshUpdatesRowsInPlace() async throws {
        let (schedule, sessionID) = (UUID(), UUID())
        await api.setOccurrences([try .make(schedule: schedule, day: "2026-09-23", name: "Old")])
        await api.setSessions([try .make(id: sessionID, startedAt: "2026-09-22T12:00:00Z")])
        let range = sync()
        try await range.refresh(days: week)
        await api.setOccurrences([try .make(schedule: schedule, day: "2026-09-23", name: "New")])
        await api.setSessions([try .make(id: sessionID, startedAt: "2026-09-22T12:05:00Z")])
        try await range.refresh(days: week)
        #expect(try classes().map(\.disciplineName) == ["New"])
        #expect(try sessions().map(\.startedAt) == [Date(timeIntervalSince1970: 1_790_078_700)])  // 12:05Z
    }

    @Test func rowsTheServerNoLongerReturnsAreDeleted() async throws {
        await api.setBlocks([try .make(day: "2026-09-22")], on: "2026-09-22")
        await api.setOccurrences([try .make(day: "2026-09-23")])
        await api.setSessions([try .make(startedAt: "2026-09-22T12:00:00Z")])
        let range = sync()
        try await range.refresh(days: week)
        await api.setBlocks([], on: "2026-09-22")
        await api.setOccurrences([])
        await api.setSessions([])
        try await range.refresh(days: week)
        #expect(try blocks().isEmpty && classes().isEmpty && sessions().isEmpty)
    }

    @Test func rowsOutsideTheRangeAreKept() async throws {
        // 2026-09-21T02:59Z is 23:59 on the 20th in UTC-3: before the week.
        await api.setBlocks([try .make(day: "2026-09-20")], on: "2026-09-20")
        await api.setOccurrences([try .make(day: "2026-09-28")])
        await api.setSessions([try .make(startedAt: "2026-09-21T02:59:00Z")])
        let range = sync()
        try await range.refresh(days: ["2026-09-20"])
        try await range.refresh(days: ["2026-09-28"])
        await api.setBlocks([], on: "2026-09-20")
        await api.setOccurrences([])
        await api.setSessions([])
        try await range.refresh(days: week)
        #expect(try blocks().count == 1 && classes().count == 1 && sessions().count == 1)
    }

    @Test func aBlockWithAPendingWriteKeepsItsLocalState() async throws {
        let block = try TimeBlockDTO.make(day: "2026-09-22")
        await api.setBlocks([block], on: "2026-09-22")
        let range = sync()
        try await range.refresh(days: week)
        try blocks().first?.notes = "Mine"
        queueWrite(for: block.id.uuidString)
        try await range.refresh(days: week)
        #expect(try blocks().map(\.notes) == ["Mine"])
        await api.setBlocks([], on: "2026-09-22")
        try await range.refresh(days: week)
        #expect(try blocks().count == 1)
    }

    @Test func aWriteQueuedWhileTheReadsAreInFlightKeepsItsBlock() async throws {
        let block = try TimeBlockDTO.make(day: "2026-09-22")
        await api.setBlocks([block], on: "2026-09-22")
        let range = sync()
        try await range.refresh(days: week)
        await api.setBlocks([], on: "2026-09-22")
        let context = container.mainContext
        await api.setDuringRangeFetch { @MainActor in
            context.insert(
                OutboxEntry(sequence: 2, method: "PATCH", path: "/p/", body: nil, subjectID: block.id.uuidString))
        }
        try await range.refresh(days: week)
        #expect(try blocks().count == 1)
    }

    @Test func aLocalPlaceholderBlockIsNeverDeleted() async throws {
        let placeholder = TimeBlockRecord(dto: try .make(day: "2026-09-22"))
        placeholder.id = "local-block"
        container.mainContext.insert(placeholder)
        try await sync().refresh(days: week)
        #expect(try blocks().map(\.id) == ["local-block"])
    }

    @Test func aCancelledClassIsStoredCancelledWithItsWeekIssue207() async throws {
        await api.setOccurrences([try .make(day: "2026-09-23", cancelled: true)])
        try await sync().refresh(days: week)
        let occurrence = try #require(try classes().first)
        #expect(occurrence.isCancelled && occurrence.week == 2)
    }

    @Test func aClassWithAPendingWriteKeepsItsLocalCancellationIssue207() async throws {
        let occurrence = try ClassOccurrenceDTO.make(day: "2026-09-23")
        await api.setOccurrences([occurrence])
        let range = sync()
        try await range.refresh(days: week)
        try classes().first?.isCancelled = true
        queueWrite(for: occurrence.id)
        try await range.refresh(days: week)
        #expect(try classes().map(\.isCancelled) == [true])
        await api.setOccurrences([])
        try await range.refresh(days: week)
        #expect(try classes().count == 1)
    }
}
