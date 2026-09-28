import Foundation
import OmakaseAPI
import SwiftData

/// Checking a subtask off in Focus, and adding one from the capture panel
/// (#286), queued like every daily-loop write.
///
///     try SubtaskWrites(context: ctx).toggle(subtask)
@MainActor
public final class SubtaskWrites {
    private let context: ModelContext
    private let queue: OutboxQueue

    public init(context: ModelContext) { (self.context, queue) = (context, OutboxQueue(context: context)) }

    public func toggle(_ subtask: SubtaskRecord) throws {
        subtask.isCompleted.toggle()
        try queue.enqueue(
            kind: "subtask.patch", method: "PATCH", path: "/api/v1/tasks/\(subtask.taskID)/subtasks/\(subtask.id)/",
            body: try OmakaseJSON.encoder.encode(["is_completed": subtask.isCompleted]), subjectID: subtask.id)
        try context.save()
    }

    /// A subtask at the end of `taskID`'s list, shown at once under a
    /// `local-` id. Its create names the task by the id it has now, so on a
    /// capture it waits for the task's own create and is rewritten when that
    /// lands. The task is its subject: while it waits, a refresh leaves the
    /// task and its list as they are here. A blank title is refused, not queued.
    ///
    ///     try SubtaskWrites(context: ctx).create(taskID: task.id, title: "Outline")
    @discardableResult
    public func create(taskID: String, title: String) throws -> SubtaskRecord {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SubtaskWriteError.blankTitle(title)
        }
        let siblings = FetchDescriptor<SubtaskRecord>(predicate: #Predicate { $0.taskID == taskID })
        let order = try context.fetchCount(siblings)
        let record = SubtaskRecord(id: "local-\(UUID().uuidString)", taskID: taskID, title: title, order: order)
        context.insert(record)
        try queue.enqueue(
            kind: "subtask.create", method: "POST", path: "/api/v1/tasks/\(taskID)/subtasks/",
            body: try OmakaseJSON.encoder.encode(CreateBody(title: title, order: order)), subjectID: taskID,
            createsLocalID: record.id)
        try context.save()
        return record
    }

    private struct CreateBody: Encodable {
        let title: String
        let order: Int
    }
}

/// A subtask write the server would refuse, caught before it is queued.
public enum SubtaskWriteError: Error, Equatable, CustomStringConvertible {
    case blankTitle(String)

    public var description: String {
        switch self {
        case .blankTitle(let raw): "subtask title \(raw.debugDescription) is blank; a subtask needs a non-blank title"
        }
    }
}

/// The server's copy of a subtask replaces the local one, unless a later
/// write is queued. A create's `local-` record takes the server's id (#286).
@MainActor
public final class SubtaskHandler: OutboxHandler {
    public let kinds = ["subtask.patch", "subtask.create"]
    private let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    public func apply(_ entry: OutboxEntry, body: Data) {
        guard let dto = try? OmakaseJSON.decoder.decode(SubtaskDTO.self, from: body) else { return }
        let serverID = dto.id.uuidString
        let localID = entry.createsLocalID ?? serverID
        let descriptor = FetchDescriptor<SubtaskRecord>(
            predicate: #Predicate { $0.id == localID || $0.id == serverID })
        guard let record = try? context.fetch(descriptor).first else { return }
        record.id = serverID
        guard !OutboxQueue(context: context).hasLaterPendingWrite(than: entry, for: [localID, serverID]) else {
            return
        }
        record.apply(dto)
    }
}
