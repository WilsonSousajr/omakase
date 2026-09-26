import Foundation
import OmakaseAPI
import SwiftData

/// Daily-loop writes: each updates the local model and appends its outbox
/// entry in one save, so a crash can't show a write that never queues or
/// queue one the UI never showed (spec, Data flow -> Writes).
///
///     try TaskWrites(context: container.mainContext).toggleCompletion(record)
@MainActor
public final class TaskWrites {
    private let context: ModelContext
    private let queue: OutboxQueue

    public init(context: ModelContext) { (self.context, queue) = (context, OutboxQueue(context: context)) }

    public func toggleCompletion(_ record: TaskRecord) throws {
        record.isCompleted.toggle()
        // Mirrors Task.save both ways (M3.1 spec, Decisions).
        (record.completedAt, record.kanbanStatus) = record.isCompleted ? (.now, "done") : (nil, "todo")
        try patch(record, body: ["is_completed": record.isCompleted])
    }

    /// A Kanban move, mirroring Task.save: into Done completes the task, out
    /// of Done uncompletes it (#156).
    public func setKanbanStatus(_ record: TaskRecord, to status: String) throws {
        record.kanbanStatus = status
        if status == "done" && !record.isCompleted { (record.isCompleted, record.completedAt) = (true, .now) }
        if status != "done" && record.isCompleted { (record.isCompleted, record.completedAt) = (false, nil) }
        try patch(record, body: ["kanban_status": status])
    }

    /// `day` nil moves the task to the backlog.
    public func reschedule(_ record: TaskRecord, to day: String?) throws {
        record.scheduledDay = day
        // An explicit null: `nil` in a synthesized Encodable is omitted (Review Focus 2).
        let value = day.map { "\"\($0)\"" } ?? "null"
        try patch(record, raw: Data(#"{"scheduled_date":\#(value)}"#.utf8))
    }

    /// A task captured now, offline or not: shown at once under a `local-` id.
    public func capture(title: String, day: String?) throws -> TaskRecord {
        let record = TaskRecord(id: "local-\(UUID().uuidString)", title: title, scheduledDay: day)
        context.insert(record)
        let body = try OmakaseJSON.encoder.encode(CaptureBody(title: title, scheduledDate: day))
        try queue.enqueue(
            kind: "task.create", method: "POST", path: "/api/v1/tasks/", body: body, subjectID: record.id,
            createsLocalID: record.id)
        try context.save()
        return record
    }

    private func patch(_ record: TaskRecord, body: some Encodable) throws {
        try patch(record, raw: try OmakaseJSON.encoder.encode(body))
    }

    private func patch(_ record: TaskRecord, raw: Data) throws {
        try queue.enqueue(
            kind: "task.patch", method: "PATCH", path: "/api/v1/tasks/\(record.id)/", body: raw, subjectID: record.id)
        try context.save()
    }

    /// On a create a missing `scheduled_date` is already null, so nil may be omitted here.
    private struct CaptureBody: Encodable {
        let title: String
        let scheduledDate: String?
    }
}
