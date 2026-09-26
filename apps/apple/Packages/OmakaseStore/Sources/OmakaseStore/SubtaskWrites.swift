import Foundation
import OmakaseAPI
import SwiftData

/// Checking a subtask off in Focus, queued like every daily-loop write.
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
}

/// The server's copy of a subtask replaces the local one, unless a later write is queued.
@MainActor
public final class SubtaskHandler: OutboxHandler {
    public let kinds = ["subtask.patch"]
    private let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    public func apply(_ entry: OutboxEntry, body: Data) {
        guard let dto = try? OmakaseJSON.decoder.decode(SubtaskDTO.self, from: body) else { return }
        let id = dto.id.uuidString
        guard !OutboxQueue(context: context).hasLaterPendingWrite(than: entry, for: [id]),
            let record = try? context.fetch(FetchDescriptor<SubtaskRecord>(predicate: #Predicate { $0.id == id })).first
        else { return }
        record.apply(dto)
    }
}
