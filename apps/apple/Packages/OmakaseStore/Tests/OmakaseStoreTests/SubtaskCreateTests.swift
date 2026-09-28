import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// A subtask added through the outbox (#286): shown at once under a `local-`
/// id, and given the server's id when its create is accepted.
@MainActor
struct SubtaskCreateTests {
    let container: ModelContainer
    let api = FakeAPIClient()
    var context: ModelContext { container.mainContext }
    var writes: SubtaskWrites { SubtaskWrites(context: context) }

    init() throws { container = try StoreSchema.container(inMemory: true) }

    func entries() throws -> [OutboxEntry] {
        try context.fetch(FetchDescriptor<OutboxEntry>(sortBy: [SortDescriptor(\.sequence)]))
    }

    func drain() async {
        let handlers = OutboxHandlers([SubtaskHandler(context: context)])
        _ = await OutboxWorker(context: context, api: api, handlers: handlers).drain()
    }

    @Test(arguments: ["", "  ", "\n"])
    func aBlankTitleIsRefusedBeforeItQueues(title: String) throws {
        #expect(throws: SubtaskWriteError.blankTitle(title)) { try writes.create(taskID: "t1", title: title) }
        #expect(try entries().isEmpty)
        #expect(try context.fetch(FetchDescriptor<SubtaskRecord>()).isEmpty)
    }

    @Test func theBlankTitleErrorNamesTheValueAndTheRule() {
        let message = SubtaskWriteError.blankTitle(" ").description
        #expect(message == #"subtask title " " is blank; a subtask needs a non-blank title"#)
    }

    @Test func aSubtaskOnAStoredTaskGoesToTheEndOfItsList() throws {
        context.insert(SubtaskRecord(dto: try .make(title: "Outline"), taskID: "t1"))
        context.insert(SubtaskRecord(dto: try .make(title: "Elsewhere"), taskID: "t2"))
        let record = try writes.create(taskID: "t1", title: "Draft")
        let entry = try #require(try entries().first)
        #expect(record.order == 1 && record.taskID == "t1")
        #expect(entry.path == "/api/v1/tasks/t1/subtasks/" && entry.createsLocalID == record.id)
        #expect(String(bytes: entry.body ?? Data(), encoding: .utf8) == #"{"order":1,"title":"Draft"}"#)
    }

    @Test func aToggleQueuedOnAnUnsentSubtaskFollowsItsServerID() async throws {
        let record = try writes.create(taskID: "t1", title: "Outline")
        try writes.toggle(record)
        let server = UUID()
        await api.script([.reply(201, #"{"id":"\#(server)","title":"Outline","is_completed":false,"order":0}"#)])
        await drain()
        let toggle = try #require(try entries().first)
        #expect(toggle.path == "/api/v1/tasks/t1/subtasks/\(server)/")
        // The queued toggle is the newer state: the create's reply must not undo it.
        #expect(record.id == server.uuidString && record.isCompleted)
    }

    @Test func aReplyForASubtaskNoLongerHereAddsNothing() throws {
        let entry = OutboxEntry(
            sequence: 1, method: "POST", path: "/api/v1/tasks/t1/subtasks/", body: nil, subjectID: "t1",
            createsLocalID: "local-gone", kind: "subtask.create")
        let reply = #"{"id":"\#(UUID())","title":"Outline","is_completed":false,"order":0}"#
        SubtaskHandler(context: context).apply(entry, body: Data(reply.utf8))
        #expect(try context.fetch(FetchDescriptor<SubtaskRecord>()).isEmpty)
    }
}
