import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// A place's open tasks (spec §5): upserted from the server, series
/// templates and skipped rows dropped, and a cached row pruned unless
/// DaySync or the outbox still owns it.
@MainActor
struct PlaceSyncTests {
    let container: ModelContainer
    let api = FakeAPIClient()
    let disciplineID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let projectID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

    init() throws { container = try StoreSchema.container(inMemory: true) }

    private var context: ModelContext { container.mainContext }
    private func all() throws -> [TaskRecord] { try context.fetch(FetchDescriptor<TaskRecord>()) }

    @Test func aRefreshUpsertsTheDisciplinesOpenTasks() async throws {
        let dto = try TaskDTO.make(title: "Read chapter 4", area: "study", discipline: disciplineID)
        await api.setOpenTasks([dto], for: .discipline(disciplineID))
        try await PlaceSync(api: api, context: context).refresh(.discipline("\(disciplineID)"), today: "2026-09-27")
        #expect(try all().map(\.title) == ["Read chapter 4"])
    }

    @Test func lifeQueriesTheAreaPersonal() async throws {
        let dto = try TaskDTO.make(title: "Buy milk", area: "personal")
        await api.setOpenTasks([dto], for: .area("personal"))
        try await PlaceSync(api: api, context: context).refresh(.life, today: "2026-09-27")
        #expect(try all().map(\.title) == ["Buy milk"])
        #expect(await api.requestedPlaceQueries == ["area:personal"])
    }

    @Test func aSeriesTemplateIsDropped() async throws {
        let template = try TaskDTO.make(title: "Weekly stand-up", project: projectID, hasRecurrence: true)
        await api.setOpenTasks([template], for: .project(projectID))
        try await PlaceSync(api: api, context: context).refresh(.project("\(projectID)"), today: "2026-09-27")
        #expect(try all().isEmpty)
    }

    @Test func aSkippedRowIsDropped() async throws {
        let skipped = try TaskDTO.make(title: "Skipped occurrence", project: projectID, isSkipped: true)
        await api.setOpenTasks([skipped], for: .project(projectID))
        try await PlaceSync(api: api, context: context).refresh(.project("\(projectID)"), today: "2026-09-27")
        #expect(try all().isEmpty)
    }

    @Test func aPendingWriteIsNotOverwritten() async throws {
        let dto = try TaskDTO.make(title: "Read chapter 4", area: "study", discipline: disciplineID)
        await api.setOpenTasks([dto], for: .discipline(disciplineID))
        let sync = PlaceSync(api: api, context: context)
        try await sync.refresh(.discipline("\(disciplineID)"), today: "2026-09-27")
        let task = try #require(try all().first)
        try TaskWrites(context: context).edit(task, changes: TaskEdit(title: "Renamed locally"))
        try await sync.refresh(.discipline("\(disciplineID)"), today: "2026-09-27")
        #expect(try all().map(\.title) == ["Renamed locally"])
    }

    @Test func anAbsentOpenRowIsPruned() async throws {
        let sync = PlaceSync(api: api, context: context)
        await api.setOpenTasks([try TaskDTO.make(title: "Gone soon", project: projectID)], for: .project(projectID))
        try await sync.refresh(.project("\(projectID)"), today: "2026-09-27")
        await api.setOpenTasks([], for: .project(projectID))
        try await sync.refresh(.project("\(projectID)"), today: "2026-09-27")
        #expect(try all().isEmpty)
    }

    @Test func aPendingWriteSurvivesBeingAbsent() async throws {
        let dto = try TaskDTO.make(title: "Read chapter 4", area: "study", discipline: disciplineID)
        await api.setOpenTasks([dto], for: .discipline(disciplineID))
        let sync = PlaceSync(api: api, context: context)
        try await sync.refresh(.discipline("\(disciplineID)"), today: "2026-09-27")
        let task = try #require(try all().first)
        // An edit, not a completion: the task must stay open to exercise the prune path.
        try TaskWrites(context: context).edit(task, changes: TaskEdit(priority: "high"))
        await api.setOpenTasks([], for: .discipline(disciplineID))
        try await sync.refresh(.discipline("\(disciplineID)"), today: "2026-09-27")
        #expect(try all().map(\.title) == ["Read chapter 4"])
    }

    @Test func aLocalRowSurvivesBeingAbsent() async throws {
        let local = TaskRecord(
            id: "local-1", title: "Captured offline",
            filing: TaskFiling(area: .study, parent: .discipline("\(disciplineID)")))
        context.insert(local)
        try context.save()
        await api.setOpenTasks([], for: .discipline(disciplineID))
        try await PlaceSync(api: api, context: context).refresh(.discipline("\(disciplineID)"), today: "2026-09-27")
        #expect(try all().map(\.id) == ["local-1"])
    }

    @Test func anOccurrenceRowSurvivesBeingAbsent() async throws {
        let occurrence = TaskRecord(
            id: "occ-series-2026-09-27", title: "Stand-up",
            filing: TaskFiling(area: .study, parent: .discipline("\(disciplineID)")))
        context.insert(occurrence)
        try context.save()
        await api.setOpenTasks([], for: .discipline(disciplineID))
        try await PlaceSync(api: api, context: context).refresh(.discipline("\(disciplineID)"), today: "2026-09-27")
        #expect(try all().map(\.id) == ["occ-series-2026-09-27"])
    }

    @Test func aRowScheduledTodaySurvivesBeingAbsent() async throws {
        let dto = try TaskDTO.make(
            title: "Read chapter 4", day: "2026-09-27", area: "study", discipline: disciplineID)
        let sync = PlaceSync(api: api, context: context)
        await api.setOpenTasks([dto], for: .discipline(disciplineID))
        try await sync.refresh(.discipline("\(disciplineID)"), today: "2026-09-27")
        await api.setOpenTasks([], for: .discipline(disciplineID))
        try await sync.refresh(.discipline("\(disciplineID)"), today: "2026-09-27")
        #expect(try all().map(\.title) == ["Read chapter 4"])
    }

    @Test func aCarriedOverRowSurvivesBeingAbsent() async throws {
        let dto = try TaskDTO.make(title: "Read chapter 4", area: "study", discipline: disciplineID)
        let sync = PlaceSync(api: api, context: context)
        await api.setOpenTasks([dto], for: .discipline(disciplineID))
        try await sync.refresh(.discipline("\(disciplineID)"), today: "2026-09-27")
        let task = try #require(try all().first)
        task.isCarriedOver = true
        await api.setOpenTasks([], for: .discipline(disciplineID))
        try await sync.refresh(.discipline("\(disciplineID)"), today: "2026-09-27")
        #expect(try all().map(\.title) == ["Read chapter 4"])
    }

    @Test func anAPIErrorKeepsTheCache() async throws {
        let dto = try TaskDTO.make(title: "Read chapter 4", area: "study", discipline: disciplineID)
        let sync = PlaceSync(api: api, context: context)
        await api.setOpenTasks([dto], for: .discipline(disciplineID))
        try await sync.refresh(.discipline("\(disciplineID)"), today: "2026-09-27")
        await api.setOpenTasksOffline(true)
        await #expect(throws: APIError.self) { try await sync.refresh(.discipline("\(disciplineID)"), today: "2026-09-27") }
        #expect(try all().count == 1)
    }

    @Test func aPlaceIDThatIsNotAUUIDThrows() async throws {
        await #expect(throws: PlaceIDError.self) {
            try await PlaceSync(api: api, context: context).refresh(.project("not-a-uuid"), today: "2026-09-27")
        }
    }
}
