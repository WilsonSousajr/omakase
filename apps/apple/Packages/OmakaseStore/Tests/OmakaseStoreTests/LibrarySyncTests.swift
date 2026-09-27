import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// Samples of the library's lists, shaped like the backend's fixtures (#223).
enum LibrarySample {
    static let workspaceID = "11111111-1111-1111-1111-111111111111"
    static let semesterID = "22222222-2222-2222-2222-222222222222"
    static let disciplineID = "33333333-3333-3333-3333-333333333333"

    static func decode<T: Decodable>(_ json: String) throws -> T {
        try OmakaseJSON.decoder.decode(T.self, from: Data(json.utf8))
    }

    static func workspace(_ id: String = workspaceID, name: String = "Client work") throws -> WorkspaceDTO {
        try decode(##"{"id":"\##(id)","name":"\##(name)","color":"#a3a3a3","project_count":1}"##)
    }

    static func project(_ id: String = "44444444-4444-4444-4444-444444444444") throws -> ProjectDTO {
        try decode(
            ##"{"id":"\##(id)","workspace":"\##(workspaceID)","name":"Thesis","description":"","##
                + ##""color":"#a3a3a3","status":"active","due_date":"2026-12-01","task_count":3}"##)
    }

    static func semester() throws -> SemesterDTO {
        try decode(
            ##"{"id":"\##(semesterID)","name":"Fall","institution":"UFRJ","start_date":"2026-08-01","##
                + ##""end_date":"2026-12-15","status":"active","rotation_weeks":2,"rotation_anchor":null}"##)
    }

    static func discipline() throws -> DisciplineDTO {
        try decode(
            ##"{"id":"\##(disciplineID)","semester":"\##(semesterID)","name":"Calculus","code":"MAT1","##
                + ##""professor":"Dr. Lovelace","color":"#3b82f6","credits":4,"status":"active"}"##)
    }

    static func schedule() throws -> ClassScheduleDTO {
        try decode(
            ##"{"id":"55555555-5555-5555-5555-555555555555","discipline":"\##(disciplineID)","day_of_week":0,"##
                + ##""start_time":"10:00:00","end_time":"11:40:00","class_type":"lecture","location":"Room 1","##
                + ##""is_active":true,"rotation_weeks_on":[1]}"##)
    }

    static func holiday() throws -> HolidayDTO {
        try decode(
            ##"{"id":"66666666-6666-6666-6666-666666666666","semester":"\##(semesterID)","name":"Easter","##
                + ##""start_date":"2026-04-03","end_date":"2026-04-10"}"##)
    }

    static func library() throws -> FakeLibrary {
        let inbox = try TaskDTO.make(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!, title: "Read the paper", day: nil)
        return FakeLibrary(
            workspaces: [try workspace()], projects: [try project()], semesters: [try semester()],
            disciplines: [try discipline()], schedules: [try schedule()], holidays: [try holiday()], inbox: [inbox])
    }
}

@MainActor
struct LibrarySyncTests {
    let container: ModelContainer
    let api = FakeAPIClient()

    init() throws { container = try StoreSchema.container(inMemory: true) }

    private var context: ModelContext { container.mainContext }
    private func all<R: PersistentModel>(_ type: R.Type) throws -> [R] { try context.fetch(FetchDescriptor<R>()) }

    @Test func aRefreshCachesEveryList() async throws {
        await api.setLibrary(try LibrarySample.library())
        try await LibrarySync(api: api, context: context).refresh()
        #expect(try all(WorkspaceRecord.self).map(\.name) == ["Client work"])
        #expect(try all(ProjectRecord.self).first?.dueDay == "2026-12-01")
        #expect(try all(SemesterRecord.self).first?.rotationWeeks == 2)
        #expect(try all(DisciplineRecord.self).first?.semesterID == LibrarySample.semesterID)
        #expect(try all(ClassScheduleRecord.self).first?.rotationWeeksOn == [1])
        #expect(try all(HolidayRecord.self).first?.endDay == "2026-04-10")
        #expect(try all(TaskRecord.self).map(\.title) == ["Read the paper"])
    }

    @Test func aSecondRefreshUpdatesAndDropsWhatTheServerNoLongerHas() async throws {
        var lists = try LibrarySample.library()
        await api.setLibrary(lists)
        let sync = LibrarySync(api: api, context: context)
        try await sync.refresh()
        lists.workspaces = [try LibrarySample.workspace(name: "Renamed")]
        (lists.projects, lists.holidays) = ([], [])
        await api.setLibrary(lists)
        try await sync.refresh()
        #expect(try all(WorkspaceRecord.self).map(\.name) == ["Renamed"])
        #expect(try all(ProjectRecord.self).isEmpty)
        #expect(try all(HolidayRecord.self).isEmpty)
    }

    @Test func anInboxTaskWithAQueuedWriteIsNotDropped() async throws {
        await api.setLibrary(try LibrarySample.library())
        let sync = LibrarySync(api: api, context: context)
        try await sync.refresh()
        let task = try #require(try all(TaskRecord.self).first)
        try TaskWrites(context: context).toggleCompletion(task)
        var lists = try LibrarySample.library()
        lists.inbox = []
        await api.setLibrary(lists)
        try await sync.refresh()
        #expect(try all(TaskRecord.self).map(\.title) == ["Read the paper"])
    }

    @Test func aScheduledTaskIsNotTheInboxsToDrop() async throws {
        let scheduled = try TaskDTO.make(title: "Today's", day: "2026-09-27")
        context.insert(TaskRecord(dto: scheduled))
        await api.setLibrary(FakeLibrary())
        try await LibrarySync(api: api, context: context).refresh()
        #expect(try all(TaskRecord.self).map(\.title) == ["Today's"])
    }

    @Test func offlineTheCacheIsUntouched() async throws {
        await api.setLibrary(try LibrarySample.library())
        let sync = LibrarySync(api: api, context: context)
        try await sync.refresh()
        await api.setLibraryOffline(true)
        await #expect(throws: APIError.self) { try await sync.refresh() }
        #expect(try all(WorkspaceRecord.self).count == 1)
    }
}
