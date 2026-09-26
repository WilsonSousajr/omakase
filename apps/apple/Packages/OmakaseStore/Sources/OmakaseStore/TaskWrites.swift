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
    public init(context: ModelContext) { self.context = context }

    public func toggleCompletion(_ record: TaskRecord) throws {
        record.isCompleted.toggle()
        record.completedAt = record.isCompleted ? .now : nil
        let body = try OmakaseJSON.encoder.encode(["is_completed": record.isCompleted])
        context.insert(
            OutboxEntry(
                sequence: try nextSequence(), method: "PATCH", path: "/api/v1/tasks/\(record.id)/", body: body,
                subjectID: record.id))
        try context.save()
    }

    /// The outbox's `onAccepted`: the server's copy of a task replaces the local one.
    public func applyServerCopy(_ entry: OutboxEntry, body: Data) {
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
        guard !hasLaterPendingWrite(than: entry, for: [localID, serverID]) else { return }
        record.apply(dto)
    }

    private func hasLaterPendingWrite(than entry: OutboxEntry, for ids: [String]) -> Bool {
        let sequence = entry.sequence
        let pending = OutboxEntry.State.pending.rawValue
        let later = FetchDescriptor<OutboxEntry>(
            predicate: #Predicate { $0.sequence > sequence && $0.stateRaw == pending })
        let subjects = ((try? context.fetch(later)) ?? []).compactMap(\.subjectID)
        return subjects.contains { ids.contains($0) }
    }

    private func nextSequence() throws -> Int {
        var descriptor = FetchDescriptor<OutboxEntry>(sortBy: [SortDescriptor(\.sequence, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try context.fetch(descriptor).first?.sequence ?? 0) + 1
    }
}
