import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// A series' computed occurrences in the cache (#206): stored under
/// `occ-<series>-<date>` until a write materializes them.
@MainActor
struct OccurrenceSyncTests {
    let container: ModelContainer
    let api = FakeAPIClient()
    let series = UUID()
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    init() throws { container = try StoreSchema.container(inMemory: true) }

    func daySync() -> DaySync {
        DaySync(
            context: container.mainContext, api: api, clock: { Date(timeIntervalSince1970: 1_772_884_800) },
            calendar: utc)
    }

    func rangeSync() -> RangeSync { RangeSync(api: api, context: container.mainContext, calendar: utc) }

    func records() throws -> [TaskRecord] {
        try container.mainContext.fetch(FetchDescriptor<TaskRecord>(sortBy: [SortDescriptor(\.id)]))
    }

    func occurrenceID(_ day: String) -> String { "occ-\(series.uuidString)-\(day)" }

    @Test func aComputedOccurrenceIsStoredUnderItsOccurrenceID() async throws {
        await api.setProfile(try .make())
        await api.setTasks([try .virtual(series: series, day: "2026-03-07")], on: "2026-03-07")
        try await daySync().refresh()
        let record = try #require(try records().first)
        #expect(record.id == occurrenceID("2026-03-07") && record.isVirtual && record.title == "Stand-up")
        #expect(record.seriesID == series.uuidString && record.occurrenceDay == "2026-03-07")
        #expect(record.scheduledDay == "2026-03-07" && record.isRepeating)
    }

    @Test func aSecondRefreshFindsTheSameOccurrence() async throws {
        await api.setProfile(try .make())
        await api.setTasks([try .virtual(series: series, day: "2026-03-07")], on: "2026-03-07")
        let sync = daySync()
        try await sync.refresh()
        try await sync.refresh()
        #expect(try records().count == 1)
    }

    @Test func aMaterializedRowReplacesTheOccurrence() async throws {
        await api.setProfile(try .make())
        await api.setTasks([try .virtual(series: series, day: "2026-03-07")], on: "2026-03-07")
        let sync = daySync()
        try await sync.refresh()
        let row = UUID()
        await api.setTasks([try .make(id: row, title: "Stand-up", series: series)], on: "2026-03-07")
        try await sync.refresh()
        let record = try #require(try records().first)
        #expect(try records().count == 1 && record.id == row.uuidString && !record.isVirtual)
        #expect(record.seriesID == series.uuidString && record.isRepeating)
    }

    @Test func aPlainTaskIsNotRepeating() async throws {
        await api.setProfile(try .make())
        await api.setTasks([try .make(title: "Once")], on: "2026-03-07")
        try await daySync().refresh()
        let record = try #require(try records().first)
        #expect(!record.isVirtual && record.seriesID == nil && record.occurrenceDay == nil && !record.isRepeating)
    }

    @Test func planReadsTheRangesOccurrences() async throws {
        let row = UUID()
        await api.setTaskOccurrences([
            try .make(id: row, title: "Gym", day: "2026-03-02", series: series),
            try .virtual(series: series, day: "2026-03-04", title: "Gym"),
        ])
        try await rangeSync().refresh(days: (2...8).map { "2026-03-0\($0)" })
        #expect(try records().map(\.id).sorted() == [row.uuidString, occurrenceID("2026-03-04")].sorted())
        #expect(await api.requestedRanges.contains("tasks 2026-03-02..2026-03-08"))
    }

    @Test func anOccurrenceGoneFromTheRangeIsRemovedButNotARow() async throws {
        await api.setTaskOccurrences([try .virtual(series: series, day: "2026-03-04")])
        let week = (2...8).map { "2026-03-0\($0)" }
        try await rangeSync().refresh(days: week)
        container.mainContext.insert(TaskRecord(id: "row", title: "Once", scheduledDay: "2026-03-05"))
        await api.setTaskOccurrences([])
        try await rangeSync().refresh(days: week)
        #expect(try records().map(\.id) == ["row"])
    }

    @Test func anOccurrenceWithAQueuedWriteOutlivesTheRange() async throws {
        await api.setTaskOccurrences([try .virtual(series: series, day: "2026-03-04")])
        let week = (2...8).map { "2026-03-0\($0)" }
        try await rangeSync().refresh(days: week)
        let id = occurrenceID("2026-03-04")
        container.mainContext.insert(
            OutboxEntry(sequence: 1, method: "PUT", path: "/x/", body: nil, subjectID: id, createsLocalID: id))
        await api.setTaskOccurrences([])
        try await rangeSync().refresh(days: week)
        #expect(try records().map(\.id) == [id])
    }

    @Test func anOccurrenceOutsideTheRangeIsLeftAlone() async throws {
        await api.setTaskOccurrences([try .virtual(series: series, day: "2026-03-04")])
        try await rangeSync().refresh(days: ["2026-03-04"])
        await api.setTaskOccurrences([])
        try await rangeSync().refresh(days: ["2026-03-05"])
        #expect(try records().count == 1)
    }
}
