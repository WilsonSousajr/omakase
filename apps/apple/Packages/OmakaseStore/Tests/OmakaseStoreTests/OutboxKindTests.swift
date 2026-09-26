import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

@MainActor
struct OutboxKindTests {
    let container: ModelContainer
    let api = FakeAPIClient()
    var context: ModelContext { container.mainContext }

    init() throws { container = try StoreSchema.container(inMemory: true) }

    func entries() throws -> [OutboxEntry] {
        try context.fetch(FetchDescriptor<OutboxEntry>(sortBy: [SortDescriptor(\.sequence)]))
    }

    func body(_ entry: OutboxEntry) -> String { String(bytes: entry.body ?? Data(), encoding: .utf8) ?? "" }

    @Test func anM1EntryWithNoKindReplaysAsATaskPatch() {
        let entry = OutboxEntry(sequence: 1, method: "PATCH", path: "/api/v1/tasks/x/", body: nil, subjectID: "x")
        #expect(entry.kind == "task.patch")
    }

    @Test func anUnknownKindParksWithoutBeingSent() async throws {
        context.insert(OutboxEntry(sequence: 1, method: "POST", path: "/x", body: nil, subjectID: nil, kind: "mystery"))
        let worker = OutboxWorker(context: context, api: api, handlers: OutboxHandlers([TaskHandler(context: context)]))
        #expect(await worker.drain() == .empty)
        let parked = try #require(try entries().first)
        #expect(parked.state == .parked && parked.lastError?.contains("mystery") == true)
        #expect(await api.sentRequests.isEmpty)
    }

    @Test func completingMovesTheTaskToDoneAndBack() throws {
        let record = TaskRecord(id: "t1", title: "T")
        context.insert(record)
        let writes = TaskWrites(context: context)
        try writes.toggleCompletion(record)
        #expect(record.isCompleted && record.kanbanStatus == "done")
        try writes.toggleCompletion(record)
        #expect(!record.isCompleted && record.kanbanStatus == "todo")
    }

    @Test func movingToDoneCompletesTheTask() throws {
        let record = TaskRecord(id: "t1", title: "T")
        context.insert(record)
        try TaskWrites(context: context).setKanbanStatus(record, to: "done")
        #expect(record.isCompleted && record.completedAt != nil)
        let entry = try #require(try entries().first)
        #expect(entry.kind == "task.patch" && body(entry) == #"{"kanban_status":"done"}"#)
    }

    @Test func movingToInProgressLeavesCompletionAlone() throws {
        let record = TaskRecord(id: "t1", title: "T")
        context.insert(record)
        try TaskWrites(context: context).setKanbanStatus(record, to: "in_progress")
        #expect(record.kanbanStatus == "in_progress" && !record.isCompleted)
    }

    @Test func reschedulingToBacklogSendsAnExplicitNull() throws {
        // Review Focus 2: a synthesized Encodable would omit nil and change nothing.
        let record = TaskRecord(id: "t1", title: "T", scheduledDay: "2026-03-07")
        context.insert(record)
        try TaskWrites(context: context).reschedule(record, to: nil)
        let entry = try #require(try entries().first)
        #expect(body(entry) == #"{"scheduled_date":null}"#)
        #expect(record.scheduledDay == nil)
    }

    @Test func reschedulingToADaySendsIt() throws {
        let record = TaskRecord(id: "t1", title: "T", scheduledDay: "2026-03-07")
        context.insert(record)
        try TaskWrites(context: context).reschedule(record, to: "2026-03-08")
        #expect(body(try #require(try entries().first)) == #"{"scheduled_date":"2026-03-08"}"#)
        #expect(record.scheduledDay == "2026-03-08")
    }

    @Test func captureQueuesACreateWithALocalID() throws {
        let record = try TaskWrites(context: context).capture(title: "Call the lab", day: "2026-03-07")
        let entry = try #require(try entries().first)
        #expect(record.id.hasPrefix("local-"))
        #expect(entry.kind == "task.create" && entry.method == "POST" && entry.createsLocalID == record.id)
        #expect(body(entry) == #"{"scheduled_date":"2026-03-07","title":"Call the lab"}"#)
    }

    @Test func anAcceptedCaptureTakesTheServerID() async throws {
        let record = try TaskWrites(context: context).capture(title: "Call the lab", day: "2026-03-07")
        let server = try TaskDTO.make(title: "Call the lab")
        let reply = String(bytes: try OmakaseJSON.encoder.encode(server), encoding: .utf8)!
        await api.script([.reply(201, reply)])
        let worker = OutboxWorker(context: context, api: api, handlers: OutboxHandlers([TaskHandler(context: context)]))
        _ = await worker.drain()
        #expect(record.id == server.id.uuidString)
    }
}
