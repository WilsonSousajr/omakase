import Foundation
import OmakaseAPI
import SwiftData

/// A block's session notes and rating (M3.3 writes them after a pomodoro).
///
///     try BlockWrites(context: ctx).rate(block, 4)
@MainActor
public final class BlockWrites {
    private let context: ModelContext
    private let queue: OutboxQueue

    public init(context: ModelContext) { (self.context, queue) = (context, OutboxQueue(context: context)) }

    public func saveNotes(_ block: TimeBlockRecord, _ notes: String) throws {
        block.notes = notes
        try patch(block, body: try OmakaseJSON.encoder.encode(["notes": notes]))
    }

    public func rate(_ block: TimeBlockRecord, _ rating: Int) throws {
        block.sessionRating = rating
        try patch(block, body: try OmakaseJSON.encoder.encode(["session_rating": rating]))
    }

    private func patch(_ block: TimeBlockRecord, body: Data) throws {
        try queue.enqueue(
            kind: "block.patch", method: "PATCH", path: "/api/v1/timeblocks/\(block.id)/", body: body,
            subjectID: block.id)
        try context.save()
    }
}

/// The server's copy of a block replaces the local one, unless a later write is queued.
@MainActor
public final class BlockHandler: OutboxHandler {
    public let kinds = ["block.patch"]
    private let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    public func apply(_ entry: OutboxEntry, body: Data) {
        guard let dto = try? OmakaseJSON.decoder.decode(TimeBlockDTO.self, from: body) else { return }
        let id = dto.id.uuidString
        guard !OutboxQueue(context: context).hasLaterPendingWrite(than: entry, for: [id]),
            let record = try? context.fetch(FetchDescriptor<TimeBlockRecord>(predicate: #Predicate { $0.id == id }))
                .first
        else { return }
        record.apply(dto)
    }
}
