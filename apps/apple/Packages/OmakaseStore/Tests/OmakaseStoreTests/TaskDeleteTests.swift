import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// Deleting a task from the Inbox (#225): offline-safe like every task write,
/// and a capture the server never saw is simply withdrawn.
@MainActor
struct TaskDeleteTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws { container = try StoreSchema.container(inMemory: true) }

    private func entries() throws -> [OutboxEntry] {
        try context.fetch(FetchDescriptor<OutboxEntry>(sortBy: [SortDescriptor(\.sequence)]))
    }

    @Test func aStoredTaskGoesNowAndItsDeleteIsQueued() throws {
        let task = TaskRecord(dto: try .make(title: "Old idea", day: nil))
        context.insert(task)
        let id = task.id
        try TaskWrites(context: context).delete(task)
        #expect(try context.fetchCount(FetchDescriptor<TaskRecord>()) == 0)
        let entry = try #require(try entries().first)
        #expect(entry.kind == "task.delete" && entry.method == "DELETE")
        #expect(entry.path == "/api/v1/tasks/\(id)/" && entry.subjectID == id)
    }

    @Test func aCaptureTheServerNeverSawIsWithdrawnNotDeleted() throws {
        let writes = TaskWrites(context: context)
        let captured = try writes.capture(title: "Typo", day: nil, filing: TaskFiling(area: .work, parent: nil))
        try writes.toggleCompletion(captured)
        try writes.delete(captured)
        #expect(try context.fetchCount(FetchDescriptor<TaskRecord>()) == 0)
        #expect(try entries().isEmpty)
    }

    @Test func deletingAnUnsentCaptureTakesItsBlocksWithItIssue275() throws {
        // #275: a slot drawn on Plan (#264) captures a task and its block together;
        // deleting that capture before it is sent must not leave the block.
        let writes = TaskWrites(context: context)
        let captured = try writes.capture(
            title: "Typo", day: "2026-03-07", filing: TaskFiling(area: .study, parent: nil))
        _ = try BlockWrites(context: context).create(
            taskID: captured.id, studyBlockID: nil, day: "2026-03-07", start: "14:00:00", end: "15:00:00")
        try writes.delete(captured)
        let blocks = try context.fetch(FetchDescriptor<TimeBlockRecord>())
        #expect(blocks.map(\.taskID).isEmpty)
        #expect(try entries().isEmpty)
    }

    @Test func theTaskHandlerTakesTheDeletesEmptyReply() {
        let handler = TaskHandler(context: context)
        #expect(handler.kinds.contains("task.delete"))
    }
}
