import Foundation
import OmakaseAPI
import SwiftData

/// A task's series (#206): its rule set or stopped, and a computed
/// occurrence made a row by its first write.
extension TaskWrites {
    /// Queues the rule for the task's series. On a computed occurrence the
    /// series is named directly, so setting a rule does not materialize it.
    public func setRecurrence(_ record: TaskRecord, rule: RepeatRule) throws {
        try queue.enqueue(
            kind: "task.recurrence", method: "PUT", path: "/api/v1/tasks/\(seriesTarget(record))/recurrence/",
            body: try OmakaseJSON.encoder.encode(rule), subjectID: record.id)
        try context.save()
    }

    /// Ends the series the day before `today`, the client's day (invariant 2).
    /// Its computed occurrences from `today` on go at once; history stays.
    public func stopRecurrence(_ record: TaskRecord, today: String) throws {
        let path = "/api/v1/tasks/\(seriesTarget(record))/recurrence/?date=\(today)"
        try queue.enqueue(kind: "task.recurrence.stop", method: "DELETE", path: path, body: nil, subjectID: record.id)
        if let seriesID = record.seriesID { try hideComputed(of: seriesID, from: today) }
        try context.save()
    }

    /// Queues the materialize PUT for a computed occurrence, carrying `body`,
    /// the first write's fields, which the server applies in the same
    /// transaction. Its reply gives the `occ-` id the row's id, in the record
    /// and in every later write (OutboxWorker's placeholder rewrite).
    func materialize(_ record: TaskRecord, body: Data) throws {
        let path = "/api/v1/tasks/\(record.seriesID ?? "")/occurrences/\(record.occurrenceDay ?? "")/"
        try queue.enqueue(
            kind: "task.materialize", method: "PUT", path: path, body: body, subjectID: record.id,
            createsLocalID: record.id)
        record.isVirtual = false
    }

    /// A block placed on a computed occurrence needs a row to point at.
    func materializeIfComputed(taskID: String) throws {
        let found = try context.fetch(FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == taskID }))
        guard let record = found.first, record.isVirtual else { return }
        try materialize(record, body: Data("{}".utf8))
    }

    private func seriesTarget(_ record: TaskRecord) -> String {
        record.isVirtual ? record.seriesID ?? record.id : record.id
    }

    private func hideComputed(of seriesID: String, from today: String) throws {
        let computed = try context.fetch(
            FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.seriesID == seriesID && $0.isVirtual }))
        for record in computed where (record.occurrenceDay ?? "") >= today { context.delete(record) }
    }
}

/// A rule write was accepted. A PUT answers with the task, now in its
/// series; one sent through the series answers with the hidden template,
/// which is not cached. A stop answers 204, with nothing to apply.
@MainActor
public final class RecurrenceHandler: OutboxHandler {
    public let kinds = ["task.recurrence", "task.recurrence.stop"]
    private let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    public func apply(_ entry: OutboxEntry, body: Data) {
        guard let dto = try? OmakaseJSON.decoder.decode(TaskDTO.self, from: body), dto.id != nil else { return }
        let id = dto.recordID
        guard let record = try? context.fetch(FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == id })).first,
            !OutboxQueue(context: context).hasLaterPendingWrite(than: entry, for: [id])
        else { return }
        record.apply(dto)
    }
}
