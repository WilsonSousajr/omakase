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
    let context: ModelContext
    let queue: OutboxQueue

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

    /// `date` nil clears the reminder. A nil Optional in a dictionary encodes
    /// as an explicit null, which the server needs to clear it (spec §2).
    public func setReminder(_ record: TaskRecord, at date: Date?) throws {
        record.remindAt = date
        try patch(record, body: ["remind_at": date])
    }

    /// The task editor's save (#218): the fields that changed, applied here
    /// and sent as one PATCH. An empty edit queues nothing.
    public func edit(_ record: TaskRecord, changes: TaskEdit) throws {
        if let title = changes.title, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TaskEditError.blankTitle(title)
        }
        guard !changes.isEmpty else { return }
        record.title = changes.title ?? record.title
        record.notes = changes.notes ?? record.notes
        record.priority = changes.priority ?? record.priority
        if let estimate = changes.estimate { record.estimatedMinutes = estimate.value }
        if let dueDay = changes.dueDay { record.dueDay = dueDay.value }
        if let filing = changes.filing {
            (record.area, record.projectID, record.disciplineID) =
                (filing.area.rawValue, filing.parent?.projectID, filing.parent?.disciplineID)
        }
        try patch(record, body: TaskEditBody(edit: changes))
    }

    /// A task captured now, offline or not: shown at once under a `local-`
    /// id. `filing` is sent as `area` plus its parent, so a capture under a
    /// project or discipline reaches the server filed the same way (spec §1).
    /// `details` adds its priority, estimate and notes (#286); its subtasks
    /// are `captureTask`'s, which the app calls.
    public func capture(
        title: String, day: String?, filing: TaskFiling, details: TaskCaptureDetails = TaskCaptureDetails()
    ) throws -> TaskRecord {
        let record = TaskRecord(id: "local-\(UUID().uuidString)", title: title, scheduledDay: day, filing: filing)
        record.priority = details.priority ?? record.priority
        (record.estimatedMinutes, record.notes) = (details.estimatedMinutes, details.notes ?? "")
        context.insert(record)
        let body = try OmakaseJSON.encoder.encode(CaptureBody(title: title, day: day, filing: filing, details: details))
        try queue.enqueue(
            kind: "task.create", method: "POST", path: "/api/v1/tasks/", body: body, subjectID: record.id,
            createsLocalID: record.id)
        try context.save()
        return record
    }

    /// Deletes the task (#225). A capture whose create was never sent is
    /// withdrawn with everything queued on it, and its local blocks (#275);
    /// otherwise the DELETE is queued, and a 404 on it counts as done (#201).
    public func delete(_ record: TaskRecord) throws {
        let id = record.id
        context.delete(record)
        if let create = queue.unsentCreate(of: id) {
            queue.withdraw(create)
            try deleteUnsentBlocks(of: id)
            try deleteUnsentSubtasks(of: id)
        } else {
            try queue.enqueue(
                kind: "task.delete", method: "DELETE", path: "/api/v1/tasks/\(id)/", body: nil, subjectID: id)
        }
        try context.save()
    }

    /// An unsent capture's blocks were never sent either: `withdraw` took
    /// their creates with the task's, so their records go too, or Plan keeps
    /// an orphan no sync will ever remove (#275).
    private func deleteUnsentBlocks(of taskID: String) throws {
        let blocks = FetchDescriptor<TimeBlockRecord>(predicate: #Predicate { $0.taskID == taskID })
        for block in try context.fetch(blocks) { context.delete(block) }
    }

    /// The same for the subtasks a capture added with it (#286): their
    /// creates went with the task's, and no refresh lists a `local-` task's.
    private func deleteUnsentSubtasks(of taskID: String) throws {
        let subtasks = FetchDescriptor<SubtaskRecord>(predicate: #Predicate { $0.taskID == taskID })
        for subtask in try context.fetch(subtasks) { context.delete(subtask) }
    }

    private func patch(_ record: TaskRecord, body: some Encodable) throws {
        try patch(record, raw: try OmakaseJSON.encoder.encode(body))
    }

    /// The first write on a computed occurrence is its materialize (#206).
    private func patch(_ record: TaskRecord, raw: Data) throws {
        if record.isVirtual {
            try materialize(record, body: raw)
        } else {
            try queue.enqueue(
                kind: "task.patch", method: "PATCH", path: "/api/v1/tasks/\(record.id)/", body: raw,
                subjectID: record.id)
        }
        try context.save()
    }

    /// On a create a missing `scheduled_date`, `project` or `discipline` is
    /// already null, so a nil may be omitted here (unlike an edit, spec §1).
    /// So may an unset `priority`, `estimated_minutes` or `description`: the
    /// server's defaults are Medium, none and empty (#286).
    private struct CaptureBody: Encodable {
        let title: String
        let scheduledDate: String?
        let area: String
        let project: String?
        let discipline: String?
        let priority: String?
        let estimatedMinutes: Int?
        let notes: String?

        enum CodingKeys: String, CodingKey {
            case title, scheduledDate, area, project, discipline, priority, estimatedMinutes
            case notes = "description"
        }

        init(title: String, day: String?, filing: TaskFiling, details: TaskCaptureDetails) {
            (self.title, scheduledDate, area) = (title, day, filing.area.rawValue)
            (project, discipline) = (filing.parent?.projectID, filing.parent?.disciplineID)
            (priority, estimatedMinutes, notes) = (details.priority, details.estimatedMinutes, details.notes)
        }
    }
}
