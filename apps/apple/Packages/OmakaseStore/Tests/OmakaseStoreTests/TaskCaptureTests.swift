import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// The capture panel's one write (glass-pass §4, #286): the task with its
/// priority, estimate and notes, a drawn slot's block, then each subtask,
/// queued behind the task's `local-` id and replayed through the real outbox.
@MainActor
struct TaskCaptureTests {
    let container: ModelContainer
    let api = FakeAPIClient()
    var context: ModelContext { container.mainContext }

    init() throws { container = try StoreSchema.container(inMemory: true) }

    static let details = TaskCaptureDetails(
        priority: "high", estimatedMinutes: 45, notes: "Ask about §3", subtasks: ["Outline", "Draft", "Send"])

    func capture(
        _ details: TaskCaptureDetails = details, slot: CaptureSlot? = nil
    ) throws -> TaskRecord {
        try TaskWrites(context: context).captureTask(
            title: "Email the advisor", day: "2026-09-28", filing: TaskFiling(area: .work, parent: nil),
            details: details, slot: slot)
    }

    func entries() throws -> [OutboxEntry] {
        try context.fetch(FetchDescriptor<OutboxEntry>(sortBy: [SortDescriptor(\.sequence)]))
    }

    func subtasks() throws -> [SubtaskRecord] {
        try context.fetch(FetchDescriptor<SubtaskRecord>(sortBy: [SortDescriptor(\.order)]))
    }

    func body(_ entry: OutboxEntry) -> String { String(bytes: entry.body ?? Data(), encoding: .utf8) ?? "" }

    func json(_ value: some Encodable) throws -> String {
        String(bytes: try OmakaseJSON.encoder.encode(value), encoding: .utf8) ?? ""
    }

    func drain() async {
        let handlers = OutboxHandlers([
            TaskHandler(context: context), SubtaskHandler(context: context), BlockHandler(context: context),
        ])
        _ = await OutboxWorker(context: context, api: api, handlers: handlers).drain()
    }

    // MARK: The task's own fields

    @Test func theDetailsJoinTheCreateBodyAndTheRecord() throws {
        let task = try capture()
        let create = try #require(try entries().first)
        let expected =
            #"{"area":"work","description":"Ask about §3","estimated_minutes":45,"priority":"high","#
            + #""scheduled_date":"2026-09-28","title":"Email the advisor"}"#
        #expect(body(create) == expected)
        #expect(task.priority == "high" && task.estimatedMinutes == 45 && task.notes == "Ask about §3")
    }

    @Test func unsetDetailsAreLeftOutOfTheBody() throws {
        let task = try capture(TaskCaptureDetails())
        let create = try #require(try entries().first)
        #expect(body(create) == #"{"area":"work","scheduled_date":"2026-09-28","title":"Email the advisor"}"#)
        #expect(task.priority == "medium" && task.estimatedMinutes == nil && task.notes.isEmpty)
    }

    // MARK: Subtasks behind the task

    @Test func subtasksAreQueuedInOrderBehindTheTask() throws {
        let task = try capture()
        let queued = try entries()
        #expect(queued.map(\.kind) == ["task.create", "subtask.create", "subtask.create", "subtask.create"])
        let creates = Array(queued.dropFirst())
        #expect(creates.allSatisfy { $0.path == "/api/v1/tasks/\(task.id)/subtasks/" && $0.method == "POST" })
        #expect(
            creates.map(body) == [
                #"{"order":0,"title":"Outline"}"#, #"{"order":1,"title":"Draft"}"#,
                #"{"order":2,"title":"Send"}"#,
            ])
        // The task is the subject: while a create waits, a refresh leaves its list alone.
        #expect(creates.allSatisfy { $0.subjectID == task.id })
        let records = try subtasks()
        #expect(records.map(\.title) == ["Outline", "Draft", "Send"])
        #expect(records.allSatisfy { $0.taskID == task.id && $0.id.hasPrefix("local-") && !$0.isCompleted })
        #expect(creates.map(\.createsLocalID) == records.map(\.id))
    }

    @Test func aSlotsBlockIsQueuedBetweenTheTaskAndItsSubtasks() throws {
        let slot = CaptureSlot(day: "2026-09-28", start: "14:00:00", end: "15:00:00")
        let task = try capture(TaskCaptureDetails(subtasks: ["Outline"]), slot: slot)
        let queued = try entries()
        #expect(queued.map(\.kind) == ["task.create", "block.create", "subtask.create"])
        #expect(body(queued[1]).contains(#""task":"\#(task.id)""#))
        #expect(body(queued[1]).contains(#""start_time":"14:00:00""#))
    }

    @Test func anAcceptedTaskRewritesItsQueuedSubtasks() async throws {
        let task = try capture()
        let localID = task.id
        let server = try TaskDTO.make(title: "Email the advisor", day: "2026-09-28")
        await api.script([.reply(201, try json(server)), .offline])
        await drain()
        let waiting = try entries()
        #expect(waiting.map(\.kind) == ["subtask.create", "subtask.create", "subtask.create"])
        #expect(waiting.allSatisfy { $0.path == "/api/v1/tasks/\(server.recordID)/subtasks/" })
        #expect(waiting.allSatisfy { $0.subjectID == server.recordID && !$0.path.contains(localID) })
        #expect(try subtasks().allSatisfy { $0.taskID == server.recordID })
    }

    @Test func acceptedSubtasksTakeTheServersIDs() async throws {
        _ = try capture(TaskCaptureDetails(subtasks: ["Outline", "Draft"]))
        let server = try TaskDTO.make(title: "Email the advisor", day: "2026-09-28")
        let (outline, draft) = (UUID(), UUID())
        await api.script([
            .reply(201, try json(server)),
            .reply(201, #"{"id":"\#(outline)","title":"Outline","is_completed":false,"order":0}"#),
            .reply(201, #"{"id":"\#(draft)","title":"Draft","is_completed":false,"order":1}"#),
        ])
        await drain()
        let sent = await api.sentRequests.map(\.path)
        let subtaskPath = "/api/v1/tasks/\(server.recordID)/subtasks/"
        #expect(sent == ["/api/v1/tasks/", subtaskPath, subtaskPath])
        #expect(try subtasks().map(\.id) == [outline.uuidString, draft.uuidString])
        #expect(try entries().isEmpty)
    }

    @Test func eachSubtaskCreateCarriesItsOwnIdempotencyKey() throws {
        _ = try capture()
        let keys = try entries().map(\.idempotencyKey)
        #expect(Set(keys).count == keys.count)
    }

    @Test func aParkedTaskCreateParksItsSubtasks() async throws {
        _ = try capture()
        await api.script([.reply(400, #"{"detail":"title too long"}"#)])
        await drain()
        let queued = try entries()
        #expect(queued.map(\.state) == [.parked, .parked, .parked, .parked])
        #expect(queued[1].lastError == "depends on a rejected create: title too long")
        #expect(await api.sentRequests.count == 1)
    }

    // MARK: A failure after the task saved (S11's review)

    @Test func aFailureAfterTheTaskSavedIsReportedWithTheTask() throws {
        var thrown: TaskCaptureError?
        do {
            _ = try capture(TaskCaptureDetails(subtasks: ["Outline", "  "]))
        } catch let error as TaskCaptureError {
            thrown = error
        }
        let task = try #require(try context.fetch(FetchDescriptor<TaskRecord>()).first)
        let error = try #require(thrown)
        let reason = SubtaskWriteError.blankTitle("  ").description
        #expect(error == .incomplete(taskID: task.id, title: "Email the advisor", reason: reason))
        #expect(error.description.contains(#"task "Email the advisor" was saved"#))
        #expect(try entries().map(\.kind) == ["task.create", "subtask.create"])
    }
}
