import Foundation
import OmakaseAPI
import SwiftData

/// A task write was accepted: the server's copy replaces the local one, and a
/// create's `local-` record takes the server's id.
@MainActor
public final class TaskHandler: OutboxHandler {
    public let kinds = ["task.patch", "task.create"]
    private let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    public func apply(_ entry: OutboxEntry, body: Data) {
        guard let dto = try? OmakaseJSON.decoder.decode(TaskDTO.self, from: body) else { return }
        let serverID = dto.id.uuidString
        let localID = entry.createsLocalID ?? serverID
        let descriptor = FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == localID || $0.id == serverID })
        guard let record = try? context.fetch(descriptor).first else {
            context.insert(TaskRecord(dto: dto))
            return
        }
        record.id = serverID
        // A later write for this task is still queued: the user's newer local
        // state stands until it is sent, as in DaySync (review finding I5).
        guard !OutboxQueue(context: context).hasLaterPendingWrite(than: entry, for: [localID, serverID]) else {
            return
        }
        record.apply(dto)
    }
}
