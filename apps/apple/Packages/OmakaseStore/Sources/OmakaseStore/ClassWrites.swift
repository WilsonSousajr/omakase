import Foundation
import OmakaseAPI
import SwiftData

/// A class cancelled on its date, and restored (#207). Each updates the
/// record at once and queues its write in one save. Both are idempotent by
/// their path (M8 spec §1), so a replay after a timeout is harmless.
///
///     try ClassWrites(context: ctx).cancel(occurrence)   // PUT …/cancellations/2026-09-23/
@MainActor
public final class ClassWrites {
    static let cancelKind = "class.cancel"
    static let restoreKind = "class.restore"

    private let context: ModelContext
    private let queue: OutboxQueue

    public init(context: ModelContext) { (self.context, queue) = (context, OutboxQueue(context: context)) }

    public func cancel(_ occurrence: ClassOccurrenceRecord) throws {
        try write(occurrence, cancelled: true, kind: Self.cancelKind, method: "PUT", undoing: Self.restoreKind)
    }

    public func restore(_ occurrence: ClassOccurrenceRecord) throws {
        try write(occurrence, cancelled: false, kind: Self.restoreKind, method: "DELETE", undoing: Self.cancelKind)
    }

    /// The opposite write still queued for this class is withdrawn instead of
    /// queueing this one: together they change nothing on the server.
    private func write(
        _ occurrence: ClassOccurrenceRecord, cancelled: Bool, kind: String, method: String, undoing opposite: String
    ) throws {
        occurrence.isCancelled = cancelled
        if let queued = unsent(opposite, for: occurrence.id) {
            context.delete(queued)
        } else {
            try queue.enqueue(
                kind: kind, method: method, path: Self.path(occurrence), body: nil, subjectID: occurrence.id)
        }
        try context.save()
    }

    private func unsent(_ kind: String, for occurrenceID: String) -> OutboxEntry? {
        (queue.entries(in: .pending) + queue.entries(in: .parked)).last {
            $0.kind == kind && $0.subjectID == occurrenceID
        }
    }

    static func path(_ occurrence: ClassOccurrenceRecord) -> String {
        let schedule = occurrence.classScheduleID.lowercased()
        return "/api/v1/study/classschedules/\(schedule)/cancellations/\(occurrence.day)/"
    }
}

/// A class write was accepted. The record already shows it, and neither
/// reply (the cancellation, or a restore's 204) holds anything more to apply.
@MainActor
public final class ClassHandler: OutboxHandler {
    public let kinds = [ClassWrites.cancelKind, ClassWrites.restoreKind]

    public init() {}

    public func apply(_ entry: OutboxEntry, body: Data) {}
}
