import Foundation
import OmakaseAPI
import SwiftData

/// A task write was accepted: the server's copy replaces the local one, and a
/// create's `local-` record, or a materialized occurrence's `occ-` one (#206),
/// takes the server's id, and the blocks and subtasks naming it follow (#274).
/// A delete's reply is empty, so nothing applies (#225).
@MainActor
public final class TaskHandler: OutboxHandler {
    public let kinds = ["task.patch", "task.create", "task.materialize", "task.delete"]
    private let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    public func apply(_ entry: OutboxEntry, body: Data) {
        guard let dto = try? OmakaseJSON.decoder.decode(TaskDTO.self, from: body), dto.id != nil else { return }
        let serverID = dto.recordID
        let localID = entry.createsLocalID ?? serverID
        let descriptor = FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == localID || $0.id == serverID })
        guard let record = try? context.fetch(descriptor).first else {
            context.insert(TaskRecord(dto: dto))
            return
        }
        record.id = serverID
        repointChildren(from: localID, to: serverID)
        // A later write for this task is still queued: the user's newer local
        // state stands until it is sent, as in DaySync (review finding I5).
        guard !OutboxQueue(context: context).hasLaterPendingWrite(than: entry, for: [localID, serverID]) else {
            return
        }
        record.apply(dto)
    }

    /// Blocks and subtasks name their task by id, so they follow it to the
    /// server's at once (#274). Otherwise a block whose own create is still
    /// queued loses its title, tint and parent on Plan, and a subtask its task
    /// for good; `BlockHandler` only corrects the block when its create lands.
    private func repointChildren(from localID: String, to serverID: String) {
        guard localID != serverID else { return }
        let blocks = FetchDescriptor<TimeBlockRecord>(predicate: #Predicate { $0.taskID == localID })
        for block in (try? context.fetch(blocks)) ?? [] { block.taskID = serverID }
        let subtasks = FetchDescriptor<SubtaskRecord>(predicate: #Predicate { $0.taskID == localID })
        for subtask in (try? context.fetch(subtasks)) ?? [] { subtask.taskID = serverID }
    }
}
