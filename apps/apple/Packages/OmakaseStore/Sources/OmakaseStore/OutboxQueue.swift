import Foundation
import SwiftData

/// Appends writes to the outbox in order, and answers whether a later write
/// for the same item is still queued. Shared by every `…Writes` and handler.
///
///     try OutboxQueue(context: ctx).enqueue(kind: "task.patch", method: "PATCH", path: p, body: b, subjectID: id)
@MainActor
public struct OutboxQueue {
    private let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    public func enqueue(
        kind: String, method: String, path: String, body: Data?, subjectID: String?, createsLocalID: String? = nil
    ) throws {
        context.insert(
            OutboxEntry(
                sequence: try nextSequence(), method: method, path: path, body: body, subjectID: subjectID,
                createsLocalID: createsLocalID, kind: kind))
    }

    /// A later write for one of `ids` is still pending: the user's newer local
    /// state stands until it is sent, as in DaySync (review finding I5).
    public func hasLaterPendingWrite(than entry: OutboxEntry, for ids: [String]) -> Bool {
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
