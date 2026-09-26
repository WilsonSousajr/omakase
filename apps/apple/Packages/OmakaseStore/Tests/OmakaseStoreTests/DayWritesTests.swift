import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

@MainActor
struct DayWritesTests {
    let container: ModelContainer
    let api = FakeAPIClient()
    var context: ModelContext { container.mainContext }

    init() throws { container = try StoreSchema.container(inMemory: true) }

    func entries() throws -> [OutboxEntry] {
        try context.fetch(FetchDescriptor<OutboxEntry>(sortBy: [SortDescriptor(\.sequence)]))
    }

    func body(_ entry: OutboxEntry) -> String { String(bytes: entry.body ?? Data(), encoding: .utf8) ?? "" }

    func allHandlers() -> OutboxHandlers {
        OutboxHandlers([
            TaskHandler(context: context), SubtaskHandler(context: context), BlockHandler(context: context),
            SessionHandler(), ReviewHandler(context: context),
        ])
    }

    func drain() async { _ = await OutboxWorker(context: context, api: api, handlers: allHandlers()).drain() }

    @Test func checkingASubtaskPatchesItUnderItsTask() throws {
        let subtask = SubtaskRecord(dto: try .make(title: "a"), taskID: "t1")
        context.insert(subtask)
        try SubtaskWrites(context: context).toggle(subtask)
        let entry = try #require(try entries().first)
        #expect(subtask.isCompleted)
        #expect(entry.kind == "subtask.patch" && entry.path == "/api/v1/tasks/t1/subtasks/\(subtask.id)/")
        #expect(body(entry) == #"{"is_completed":true}"#)
    }

    @Test func anAcceptedSubtaskTakesTheServersCopy() async throws {
        let id = UUID()
        let subtask = SubtaskRecord(dto: try .make(id: id, title: "a"), taskID: "t1")
        context.insert(subtask)
        try SubtaskWrites(context: context).toggle(subtask)
        await api.script([.reply(200, #"{"id":"\#(id)","title":"a (edited)","is_completed":true,"order":0}"#)])
        await drain()
        #expect(subtask.title == "a (edited)" && subtask.isCompleted)
    }

    @Test func notesAndRatingPatchTheBlock() throws {
        let block = TimeBlockRecord(dto: try .make(day: "2026-03-07"))
        context.insert(block)
        let writes = BlockWrites(context: context)
        try writes.saveNotes(block, "Drafted §2")
        try writes.rate(block, 4)
        let queued = try entries()
        #expect(queued.map(\.kind) == ["block.patch", "block.patch"])
        #expect(queued.map(\.path) == Array(repeating: "/api/v1/timeblocks/\(block.id)/", count: 2))
        #expect(queued.map(body) == [#"{"notes":"Drafted §2"}"#, #"{"session_rating":4}"#])
        #expect(block.notes == "Drafted §2" && block.sessionRating == 4)
    }

    @Test func anAcceptedBlockTakesTheServersCopy() async throws {
        let block = TimeBlockRecord(dto: try .make(day: "2026-03-07"))
        context.insert(block)
        try BlockWrites(context: context).rate(block, 4)
        let server = try TimeBlockDTO.make(id: UUID(uuidString: block.id)!, day: "2026-03-07")
        await api.script([.reply(200, String(bytes: try OmakaseJSON.encoder.encode(server), encoding: .utf8)!)])
        await drain()
        #expect(block.sessionRating == nil)  // the server's copy (unrated) is applied once accepted
    }

    @Test func aSessionPostsTheMacsClockAndItsBlock() throws {
        let started = Date(timeIntervalSince1970: 1_772_874_000)  // 2026-03-07 09:00 UTC
        try SessionWrites(context: context).record(
            FinishedSession(
                taskID: "t1", timeBlockID: "b1", type: "focus", minutes: 25, startedAt: started,
                endedAt: started.addingTimeInterval(1500), completed: true))
        let entry = try #require(try entries().first)
        #expect(entry.kind == "session.create" && entry.method == "POST" && entry.path == "/api/v1/pomodoro/sessions/")
        #expect(body(entry).contains(#""started_at":"2026-03-07T09:00:00.000Z""#))
        #expect(body(entry).contains(#""time_block":"b1""#) && body(entry).contains(#""session_type":"focus""#))
    }

    @Test func aSessionOnACapturedTaskSendsTheServerID() async throws {
        // Review Focus 3: the capture's local id is rewritten before the session is sent.
        let task = try TaskWrites(context: context).capture(title: "New", day: "2026-03-07")
        try SessionWrites(context: context).record(
            FinishedSession(
                taskID: task.id, timeBlockID: nil, type: "focus", minutes: 25,
                startedAt: .now.addingTimeInterval(-1500), endedAt: .now, completed: true))
        let server = try TaskDTO.make(title: "New")
        let created = String(bytes: try OmakaseJSON.encoder.encode(server), encoding: .utf8)!
        await api.script([.reply(201, created), .reply(201, "{}")])
        await drain()
        let sent = await api.sentRequests
        let sessionBody = String(bytes: try #require(sent.last?.body), encoding: .utf8)!
        #expect(sent.count == 2 && sessionBody.contains(server.id.uuidString) && !sessionBody.contains("local-"))
    }

    @Test func applyingASessionReplyChangesNothingLocal() throws {
        // Sessions are not cached until M3.3 shows history.
        let entry = OutboxEntry(sequence: 1, method: "POST", path: "/x", body: nil, subjectID: nil, kind: "session.create")
        SessionHandler().apply(entry, body: Data("{}".utf8))
        #expect(try context.fetch(FetchDescriptor<TaskRecord>()).isEmpty)
    }

    @Test func aReviewPutsByDateAndKeepsItsLocalRecord() throws {
        try ReviewWrites(context: context).save(day: "2026-03-07", rating: 4, win: "M3.1", energy: 2, shutdown: true)
        let entry = try #require(try entries().first)
        #expect(entry.kind == "review.put" && entry.method == "PUT")
        #expect(entry.path == "/api/v1/stats/reviews/by-date/2026-03-07/")
        #expect(entry.subjectID == DailyReviewRecord.subjectID(for: "2026-03-07"))
        #expect(body(entry).contains(#""energy":2"#) && body(entry).contains(#""is_shutdown":true"#))
        let record = try #require(try context.fetch(FetchDescriptor<DailyReviewRecord>()).first)
        #expect(record.energy == 2 && record.isShutdown && record.win == "M3.1" && record.rating == 4)
    }

    @Test func savingAReviewTwiceUpdatesOneRecord() throws {
        let writes = ReviewWrites(context: context)
        try writes.save(day: "2026-03-07", rating: 3, win: "", energy: nil, shutdown: false)
        try writes.save(day: "2026-03-07", rating: 5, win: "", energy: 1, shutdown: false)
        let records = try context.fetch(FetchDescriptor<DailyReviewRecord>())
        #expect(records.count == 1 && records.first?.rating == 5)
    }

    @Test func anAcceptedReviewTakesTheServersCopy() async throws {
        try ReviewWrites(context: context).save(day: "2026-03-07", rating: 4, win: "", energy: 2, shutdown: true)
        let reply =
            #"{"id":"\#(UUID())","date":"2026-03-07","productivity_rating":4,"win_of_the_day":"","#
            + #""energy":2,"is_shutdown":true,"shutdown_at":"2026-03-07T22:00:00Z"}"#
        await api.script([.reply(200, reply)])
        await drain()
        #expect(try context.fetch(FetchDescriptor<DailyReviewRecord>()).first?.shutdownAt != nil)
    }

    @Test func everyKindTheWritesQueueHasAHandler() {
        let handlers = allHandlers()
        for kind in ["task.patch", "task.create", "subtask.patch", "block.patch", "session.create", "review.put"] {
            #expect(handlers.handles(kind), "no handler for \(kind)")
        }
    }
}
