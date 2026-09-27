import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// A slot drawn on Plan and saved with ⏎ (spec §9, #264): the app captures
/// the task on the slot's day, then creates its block naming the `local-`
/// id, in one write. These replay that sequence through the real outbox.
@MainActor
struct SlotCaptureTests {
    let container: ModelContainer
    let api = FakeAPIClient()
    var context: ModelContext { container.mainContext }

    init() throws { container = try StoreSchema.container(inMemory: true) }

    /// What `AppServices.capture` does for a `.slot`: the task on the
    /// slot's day, so no reschedule is queued, then its block.
    func captureSlot() throws -> (task: TaskRecord, block: TimeBlockRecord) {
        let task = try TaskWrites(context: context).capture(
            title: "Read chapter 4", day: "2026-09-28", filing: TaskFiling(area: .study, parent: nil))
        let block = try BlockWrites(context: context).create(
            taskID: task.id, studyBlockID: nil, day: "2026-09-28", start: "14:00:00", end: "15:00:00")
        return (task, block)
    }

    func entries() throws -> [OutboxEntry] {
        try context.fetch(FetchDescriptor<OutboxEntry>(sortBy: [SortDescriptor(\.sequence)]))
    }

    func body(_ entry: OutboxEntry) -> String { String(bytes: entry.body ?? Data(), encoding: .utf8) ?? "" }

    func json(_ value: some Encodable) throws -> String {
        String(bytes: try OmakaseJSON.encoder.encode(value), encoding: .utf8) ?? ""
    }

    func drain() async {
        let handlers = OutboxHandlers([TaskHandler(context: context), BlockHandler(context: context)])
        _ = await OutboxWorker(context: context, api: api, handlers: handlers).drain()
    }

    @Test func theTaskIsQueuedBeforeItsBlockAndTheBlockNamesItsLocalID() throws {
        let (task, block) = try captureSlot()
        let queued = try entries()
        #expect(queued.map(\.kind) == ["task.create", "block.create"])
        #expect(task.id.hasPrefix("local-") && block.taskID == task.id)
        #expect(body(queued[1]).contains(#""task":"\#(task.id)""#))
        #expect(body(queued[1]).contains(#""start_time":"14:00:00""#))
    }

    @Test func anAcceptedTaskGivesTheQueuedBlockAndItsRecordTheServersID() async throws {
        let (task, block) = try captureSlot()
        let localID = task.id
        let serverTask = try TaskDTO.make(title: "Read chapter 4", day: "2026-09-28", area: "study")
        await api.script([.reply(201, try json(serverTask)), .offline])
        await drain()
        let waiting = try #require(try entries().first)
        #expect(waiting.kind == "block.create")
        #expect(body(waiting).contains(serverTask.recordID) && !body(waiting).contains(localID))
        #expect(task.id == serverTask.recordID)
        #expect(block.taskID == serverTask.recordID)
    }

    @Test func aParkedTaskCreateParksItsBlock() async throws {
        _ = try captureSlot()
        await api.script([.reply(400, #"{"detail":"title too long"}"#)])
        await drain()
        let queued = try entries()
        #expect(queued.map(\.state) == [.parked, .parked])
        #expect(queued[1].lastError == "depends on a rejected create: title too long")
        #expect(await api.sentRequests.count == 1)
    }
}
