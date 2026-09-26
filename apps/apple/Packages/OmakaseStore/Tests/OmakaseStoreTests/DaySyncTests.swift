import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// A settable clock for tests: the day can roll over mid-test.
final class TestClock: @unchecked Sendable {
    var now: Date
    init(_ now: Date) { self.now = now }
}

@MainActor
struct DaySyncTests {
    let container: ModelContainer
    let api = FakeAPIClient()
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
    let clock = TestClock(Date(timeIntervalSince1970: 1_772_884_800))  // 2026-03-07 12:00 UTC

    init() throws { container = try StoreSchema.container(inMemory: true) }

    func sync() -> DaySync {
        let clock = self.clock
        return DaySync(context: container.mainContext, api: api, clock: { clock.now }, calendar: utc)
    }

    func records() throws -> [TaskRecord] { try container.mainContext.fetch(FetchDescriptor<TaskRecord>()) }

    @Test func refreshStoresTodaysTasks() async throws {
        await api.setTasks([try .make(title: "Write spec")], on: "2026-03-07")
        try await sync().refresh()
        #expect(try records().map(\.title) == ["Write spec"])
    }

    @Test func aTaskGoneFromTheServerIsRemoved() async throws {
        await api.setTasks([try .make(title: "Old")], on: "2026-03-07")
        let today = sync()
        try await today.refresh()
        await api.setTasks([], on: "2026-03-07")
        try await today.refresh()
        #expect(try records().isEmpty)
    }

    @Test func anItemWithQueuedWritesKeepsItsLocalState() async throws {
        let task = try TaskDTO.make(title: "Mine", completed: false)
        await api.setTasks([task], on: "2026-03-07")
        let today = sync()
        try await today.refresh()
        let record = try #require(try records().first)
        record.isCompleted = true
        container.mainContext.insert(
            OutboxEntry(
                sequence: 1, method: "PATCH", path: "/api/v1/tasks/\(task.id)/", body: nil,
                subjectID: task.id.uuidString))
        try await today.refresh()
        #expect(try records().first?.isCompleted == true)
    }

    @Test func todayIsRecomputedFromTheClock() async throws {
        // Review Focus 2: the day rolls over while the app stays open.
        await api.setTasks([try .make(title: "Friday", day: "2026-03-07")], on: "2026-03-07")
        await api.setTasks([try .make(title: "Saturday", day: "2026-03-08")], on: "2026-03-08")
        let today = sync()
        try await today.refresh()
        clock.now = clock.now.addingTimeInterval(86_400)
        try await today.refresh()
        #expect(try records().map(\.title).sorted() == ["Friday", "Saturday"])
    }

    @Test func aRefreshKeepsOtherDaysAndLocalPlaceholders() async throws {
        await api.setTasks([try .make(title: "Other day", day: "2026-03-06")], on: "2026-03-06")
        let yesterday = DaySync(
            context: container.mainContext, api: api, clock: { Date(timeIntervalSince1970: 1_772_798_400) },
            calendar: utc)
        try await yesterday.refresh()
        let placeholder = TaskRecord(dto: try .make(title: "Captured offline"))
        placeholder.id = "local-1"
        container.mainContext.insert(placeholder)
        try await sync().refresh()
        #expect(try records().map(\.title).sorted() == ["Captured offline", "Other day"])
    }

    @Test func aRefreshUpdatesAnExistingRecordInPlace() async throws {
        let id = UUID()
        await api.setTasks([try .make(id: id, title: "Draft")], on: "2026-03-07")
        let today = sync()
        try await today.refresh()
        await api.setTasks([try .make(id: id, title: "Renamed on server", completed: true)], on: "2026-03-07")
        try await today.refresh()
        let only = try #require(try records().first)
        #expect(try records().count == 1 && only.title == "Renamed on server" && only.isCompleted)
    }

    @Test func anOutboxEntryStartsPendingAndStoresItsState() {
        let entry = OutboxEntry(sequence: 1, method: "PATCH", path: "/x/", body: nil, subjectID: nil)
        #expect(entry.state == .pending && entry.attempts == 0 && !entry.idempotencyKey.isEmpty)
        entry.state = .parked
        #expect(entry.stateRaw == "parked" && entry.state == .parked)
    }
}
