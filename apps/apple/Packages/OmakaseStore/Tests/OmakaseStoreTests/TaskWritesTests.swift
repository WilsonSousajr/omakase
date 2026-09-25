import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

@MainActor
struct TaskWritesTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws { container = try StoreSchema.container(inMemory: true) }

    func seeded(completed: Bool = false) throws -> TaskRecord {
        let record = TaskRecord(dto: try .make(completed: completed))
        context.insert(record)
        try context.save()
        return record
    }

    func outbox() throws -> [OutboxEntry] {
        try context.fetch(FetchDescriptor<OutboxEntry>(sortBy: [SortDescriptor(\.sequence)]))
    }

    @Test func toggleUpdatesTheModelAndQueuesOnePatch() throws {
        let record = try seeded()
        try TaskWrites(context: context).toggleCompletion(record)
        let entry = try #require(try outbox().first)
        #expect(record.isCompleted && record.completedAt != nil)
        #expect(entry.method == "PATCH" && entry.path == "/api/v1/tasks/\(record.id)/" && entry.subjectID == record.id)
        #expect(String(bytes: entry.body ?? Data(), encoding: .utf8) == #"{"is_completed":true}"#)
    }

    @Test func twoTogglesReplayInOrder() async throws {
        // Review Focus 5: complete, then undo, both offline.
        let record = try seeded()
        let writes = TaskWrites(context: context)
        try writes.toggleCompletion(record)
        try writes.toggleCompletion(record)
        let api = FakeAPIClient()
        await api.script([.reply(200, "{}"), .reply(200, "{}")])
        _ = await OutboxWorker(context: context, api: api, onAccepted: { _, _ in }).drain()
        let bodies = await api.sentRequests.map { String(bytes: $0.body ?? Data(), encoding: .utf8) ?? "" }
        #expect(bodies == [#"{"is_completed":true}"#, #"{"is_completed":false}"#])
        #expect(record.completedAt == nil)
    }

    @Test func writeSurvivesANewContextOnTheSameContainer() throws {
        // Review Focus 1: the app quit between enqueue and send. A fresh
        // context on the same container (as on relaunch) still sees the entry.
        let record = try seeded()
        try TaskWrites(context: context).toggleCompletion(record)
        let relaunched = ModelContext(container)
        #expect(try relaunched.fetch(FetchDescriptor<OutboxEntry>()).count == 1)
    }

    @Test func theServerCopyIsAppliedOnAccept() throws {
        let record = try seeded()
        let server = try TaskDTO.make(id: UUID(uuidString: record.id)!, title: "Renamed on server", completed: true)
        let entry = OutboxEntry(sequence: 1, method: "PATCH", path: "/x/", body: nil, subjectID: record.id)
        TaskWrites(context: context).applyServerCopy(entry, body: try OmakaseJSON.encoder.encode(server))
        #expect(record.title == "Renamed on server" && record.isCompleted)
    }

    @Test func anAcceptedCreateTakesTheServersID() throws {
        let local = try seeded()
        local.id = "local-7"
        let server = try TaskDTO.make(title: "Captured")
        let entry = OutboxEntry(
            sequence: 1, method: "POST", path: "/api/v1/tasks/", body: nil, subjectID: "local-7",
            createsLocalID: "local-7")
        TaskWrites(context: context).applyServerCopy(entry, body: try OmakaseJSON.encoder.encode(server))
        #expect(local.id == server.id.uuidString && local.title == "Captured")
    }

    @Test func aBodyThatIsNotATaskChangesNothing() throws {
        let record = try seeded()
        let entry = OutboxEntry(sequence: 1, method: "PATCH", path: "/x/", body: nil, subjectID: record.id)
        TaskWrites(context: context).applyServerCopy(entry, body: Data("{}".utf8))
        let count = try context.fetch(FetchDescriptor<TaskRecord>()).count
        #expect(record.title == "Task" && count == 1)
    }

    @Test func aRecordCanBeBuiltWithoutAServerCopy() {
        let record = TaskRecord(id: "local-3", title: "Captured", priority: "high", isCompleted: false)
        #expect(record.id == "local-3" && record.priority == "high" && record.scheduledDay == nil)
        #expect(record.completedAt == nil && !record.isCompleted)
    }

    @Test func acceptingAnEarlierWriteKeepsALaterQueuedChange() async throws {
        // Review finding I5: complete then undo while offline; the first
        // PATCH is accepted, the connection drops before the second. The
        // server's copy (completed) must not overwrite the queued undo.
        let record = try seeded()
        let writes = TaskWrites(context: context)
        try writes.toggleCompletion(record)
        try writes.toggleCompletion(record)
        let serverCopy = try TaskDTO.make(id: UUID(uuidString: record.id)!, completed: true)
        let api = FakeAPIClient()
        let body = String(bytes: try OmakaseJSON.encoder.encode(serverCopy), encoding: .utf8) ?? ""
        await api.script([.reply(200, body), .offline])
        _ = await OutboxWorker(context: context, api: api, onAccepted: writes.applyServerCopy).drain()
        #expect(record.isCompleted == false)
        #expect(try outbox().count == 1)
    }
}
