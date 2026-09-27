import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// Plan's block writes (#201): create, move and delete through the outbox.
@MainActor
struct BlockWritesTests {
    let container: ModelContainer
    let api = FakeAPIClient()
    var context: ModelContext { container.mainContext }
    var writes: BlockWrites { BlockWrites(context: context) }

    init() throws { container = try StoreSchema.container(inMemory: true) }

    func entries() throws -> [OutboxEntry] {
        try context.fetch(FetchDescriptor<OutboxEntry>(sortBy: [SortDescriptor(\.sequence)]))
    }

    func blocks() throws -> [TimeBlockRecord] { try context.fetch(FetchDescriptor<TimeBlockRecord>()) }

    func body(_ entry: OutboxEntry) -> String { String(bytes: entry.body ?? Data(), encoding: .utf8) ?? "" }

    func seededTask(on day: String? = "2026-03-07") throws -> TaskRecord {
        let task = TaskRecord(dto: try .make(day: day))
        context.insert(task)
        try context.save()
        return task
    }

    func seededBlock(taskID: String?, day: String = "2026-03-07") throws -> TimeBlockRecord {
        let block = TimeBlockRecord(dto: try .make(day: day, task: taskID.flatMap(UUID.init(uuidString:))))
        context.insert(block)
        try context.save()
        return block
    }

    func json(_ value: some Encodable) throws -> String {
        String(bytes: try OmakaseJSON.encoder.encode(value), encoding: .utf8) ?? ""
    }

    func drain() async {
        let handlers = OutboxHandlers([TaskHandler(context: context), BlockHandler(context: context)])
        _ = await OutboxWorker(context: context, api: api, handlers: handlers).drain()
    }

    @Test func aCreatedBlockShowsAtOnceAndQueuesAPost() throws {
        let task = try seededTask()
        let block = try writes.create(
            taskID: task.id, studyBlockID: nil, day: "2026-03-07", start: "09:00:00", end: "10:00:00")
        let entry = try #require(try entries().first)
        #expect(block.id.hasPrefix("local-"))
        #expect(try blocks().map(\.id) == [block.id])
        #expect(
            (block.day, block.startTime, block.endTime, block.taskID) == ("2026-03-07", "09:00:00", "10:00:00", task.id)
        )
        #expect(entry.kind == "block.create" && entry.method == "POST" && entry.path == "/api/v1/timeblocks/")
        #expect(entry.createsLocalID == block.id && entry.subjectID == block.id)
        #expect(
            body(entry)
                == #"{"date":"2026-03-07","end_time":"10:00:00","start_time":"09:00:00","task":"\#(task.id)"}"#)
        #expect(try entries().count == 1)
    }

    @Test func aStudyBlockParentIsSentAsStudyBlock() throws {
        let block = try writes.create(
            taskID: nil, studyBlockID: "s1", day: "2026-03-07", start: "09:00:00", end: "10:00:00")
        #expect(block.studyBlockID == "s1" && block.taskID == nil)
        #expect(
            try entries().map(body) == [
                #"{"date":"2026-03-07","end_time":"10:00:00","start_time":"09:00:00","study_block":"s1"}"#
            ])
    }

    @Test(arguments: [(nil, nil), ("t1", "s1")] as [(String?, String?)])
    func aBlockNeedsExactlyOneParent(taskID: String?, studyBlockID: String?) throws {
        let failure = BlockWrites.Failure.parentCount(taskID: taskID, studyBlockID: studyBlockID)
        #expect(throws: failure) {
            try writes.create(
                taskID: taskID, studyBlockID: studyBlockID, day: "2026-03-07", start: "09:00:00", end: "10:00:00")
        }
        #expect("\(failure)".contains("exactly one") && "\(failure)".contains(taskID ?? "nil"))
        #expect(try blocks().isEmpty)
        #expect(try entries().isEmpty)
    }

    @Test func creatingOnAnotherDayReschedulesTheTask() throws {
        let task = try seededTask(on: "2026-03-07")
        _ = try writes.create(taskID: task.id, studyBlockID: nil, day: "2026-03-09", start: "09:00:00", end: "10:00:00")
        let queued = try entries()
        #expect(task.scheduledDay == "2026-03-09")
        #expect(queued.map(\.kind) == ["block.create", "task.patch"])
        #expect(body(queued[1]) == #"{"scheduled_date":"2026-03-09"}"#)
    }

    @Test func aBlockOnACapturedTaskIsSentWithTheTasksServerID() async throws {
        let task = try TaskWrites(context: context).capture(
            title: "Offline", day: "2026-03-07", filing: TaskFiling(area: .work, parent: nil))
        let block = try writes.create(
            taskID: task.id, studyBlockID: nil, day: "2026-03-07", start: "09:00:00", end: "10:00:00")
        let serverTask = try TaskDTO.make(title: "Offline")
        let serverBlock = try TimeBlockDTO.make(day: "2026-03-07", task: serverTask.id)
        await api.script([.reply(201, try json(serverTask)), .reply(201, try json(serverBlock))])
        await drain()
        let sent = await api.sentRequests
        #expect(sent.map(\.path) == ["/api/v1/tasks/", "/api/v1/timeblocks/"])
        #expect(String(bytes: sent[1].body ?? Data(), encoding: .utf8)?.contains(serverTask.recordID) == true)
        #expect(block.id == serverBlock.id.uuidString && block.taskID == serverTask.recordID)
        #expect(try entries().isEmpty)
    }

    @Test func anAcceptedCreateKeepsALaterMoveButTakesTheServersIDs() async throws {
        let task = try TaskWrites(context: context).capture(
            title: "Offline", day: "2026-03-07", filing: TaskFiling(area: .work, parent: nil))
        let block = try writes.create(
            taskID: task.id, studyBlockID: nil, day: "2026-03-07", start: "09:00:00", end: "10:00:00")
        try writes.move(block, day: "2026-03-07", start: "11:00:00", end: "12:00:00")
        let serverTask = try TaskDTO.make(title: "Offline")
        let serverBlock = try TimeBlockDTO.make(day: "2026-03-07", task: serverTask.id)
        await api.script([.reply(201, try json(serverTask)), .reply(201, try json(serverBlock)), .offline])
        await drain()
        #expect(block.id == serverBlock.id.uuidString && block.taskID == serverTask.recordID)
        #expect(block.startTime == "11:00:00")
        #expect(try entries().map(\.path) == ["/api/v1/timeblocks/\(serverBlock.id.uuidString)/"])
    }

    @Test func movingABlockPatchesItsDayAndTimes() throws {
        let task = try seededTask()
        let block = try seededBlock(taskID: task.id)
        try writes.move(block, day: "2026-03-07", start: "13:15:00", end: "14:15:00")
        let entry = try #require(try entries().first)
        #expect((block.day, block.startTime, block.endTime) == ("2026-03-07", "13:15:00", "14:15:00"))
        #expect(entry.kind == "block.patch" && entry.path == "/api/v1/timeblocks/\(block.id)/")
        #expect(body(entry) == #"{"date":"2026-03-07","end_time":"14:15:00","start_time":"13:15:00"}"#)
        #expect(try entries().count == 1)
    }

    @Test func movingToAnotherDayReschedulesTheTask() throws {
        let task = try seededTask()
        let block = try seededBlock(taskID: task.id)
        try writes.move(block, day: "2026-03-10", start: "09:00:00", end: "10:00:00")
        #expect(try entries().map(\.kind) == ["block.patch", "task.patch"])
        #expect(task.scheduledDay == "2026-03-10")
    }

    @Test func movingAStudyBlocksBlockQueuesOnlyTheBlock() throws {
        // Study blocks aren't cached until M5, so their date isn't synced (M4 spec, Decisions).
        let block = try seededBlock(taskID: nil)
        (block.taskID, block.studyBlockID) = (nil, "s1")
        try writes.move(block, day: "2026-03-10", start: "09:00:00", end: "10:00:00")
        #expect(try entries().map(\.kind) == ["block.patch"])
    }

    @Test func notesStillPatchAfterAMove() throws {
        let block = try seededBlock(taskID: nil)
        try writes.move(block, day: "2026-03-07", start: "09:30:00", end: "10:30:00")
        try writes.saveNotes(block, "Drafted")
        #expect(try entries().map(body).last == #"{"notes":"Drafted"}"#)
    }

    @Test func deletingABlockQueuesADelete() throws {
        let block = try seededBlock(taskID: nil)
        let id = block.id
        try writes.delete(block)
        let entry = try #require(try entries().first)
        #expect(try blocks().isEmpty)
        #expect(entry.kind == "block.delete" && entry.method == "DELETE" && entry.body == nil)
        #expect(entry.path == "/api/v1/timeblocks/\(id)/" && entry.subjectID == id)
    }

    @Test func deletingAnUnsentBlockWithdrawsItsCreateAndItsMoves() throws {
        let other = try seededBlock(taskID: nil)
        try writes.saveNotes(other, "Kept")
        let block = try writes.create(
            taskID: nil, studyBlockID: "s1", day: "2026-03-07", start: "09:00:00", end: "10:00:00")
        try writes.move(block, day: "2026-03-07", start: "10:00:00", end: "11:00:00")
        try writes.delete(block)
        #expect(try blocks().map(\.id) == [other.id])
        #expect(try entries().map(body) == [#"{"notes":"Kept"}"#])
    }

    @Test(arguments: [204, 404])
    func anAcceptedOrAlreadyGoneDeleteLeavesNothingQueued(status: Int) async throws {
        let block = try seededBlock(taskID: nil)
        try writes.delete(block)
        await api.script([.reply(status, status == 404 ? #"{"detail":"Not found."}"# : "")])
        await drain()
        #expect(try entries().isEmpty)
        #expect(try blocks().isEmpty)
    }
}
