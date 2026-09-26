import Foundation
import SwiftData

/// A write the server rejected, as the failed-writes sheet shows it (M3.5 spec, Decisions).
public struct ParkedWrite: Equatable, Identifiable, Sendable {
    public let sequence: Int
    public let kind: String
    public let subjectID: String?
    public let lastError: String?
    public let createdAt: Date
    public let method: String
    public let path: String

    public var id: Int { sequence }

    public init(
        sequence: Int, kind: String, subjectID: String?, lastError: String?, createdAt: Date, method: String,
        path: String
    ) {
        (self.sequence, self.kind, self.subjectID, self.lastError) = (sequence, kind, subjectID, lastError)
        (self.createdAt, self.method, self.path) = (createdAt, method, path)
    }

    init(_ entry: OutboxEntry) {
        self.init(
            sequence: entry.sequence, kind: entry.kind, subjectID: entry.subjectID, lastError: entry.lastError,
            createdAt: entry.createdAt, method: entry.method, path: entry.path)
    }
}

/// What the outbox holds: how many writes wait, which were rejected, and when
/// the next backed-off write is due.
///
///     let status = OutboxMaintenance(context: ctx).status()
///     if !status.parked.isEmpty { showFailedWrites(status.parked) }
public struct OutboxStatus: Equatable, Sendable {
    public let pendingCount: Int
    public let parked: [ParkedWrite]
    /// The earliest backoff among pending writes; nil when none is backing off.
    public let nextAttemptAt: Date?

    public init(pendingCount: Int, parked: [ParkedWrite], nextAttemptAt: Date?) {
        (self.pendingCount, self.parked, self.nextAttemptAt) = (pendingCount, parked, nextAttemptAt)
    }
}

/// The user's hands on the outbox: list it, retry a parked write, or discard one.
///
///     let maintenance = OutboxMaintenance(context: ctx)
///     try maintenance.retry(sequence: status.parked[0].sequence)
@MainActor
public struct OutboxMaintenance {
    private let context: ModelContext
    private let queue: OutboxQueue

    public init(context: ModelContext) { (self.context, queue) = (context, OutboxQueue(context: context)) }

    public func status() -> OutboxStatus {
        let pending = queue.entries(in: .pending)
        return OutboxStatus(
            pendingCount: pending.count, parked: queue.entries(in: .parked).map(ParkedWrite.init),
            nextAttemptAt: pending.compactMap(\.nextAttemptAt).min())
    }
}
