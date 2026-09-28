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
    public enum Failure: Error, Equatable, CustomStringConvertible {
        case noEntry(sequence: Int)

        public var description: String {
            switch self {
            case .noEntry(let sequence): "no outbox entry with sequence \(sequence); it was sent or discarded"
            }
        }
    }

    private let context: ModelContext
    private let queue: OutboxQueue

    public init(context: ModelContext) { (self.context, queue) = (context, OutboxQueue(context: context)) }

    public func status() -> OutboxStatus {
        let pending = queue.entries(in: .pending)
        return OutboxStatus(
            pendingCount: pending.count, parked: queue.entries(in: .parked).map(ParkedWrite.init),
            nextAttemptAt: pending.compactMap(\.nextAttemptAt).min())
    }

    /// Sends a parked write again from a clean slate, with the writes parked
    /// because they depend on it. The next drain picks them up.
    public func retry(sequence: Int) throws {
        let entry = try entry(sequence)
        for retried in [entry] + OutboxRules.dependents(of: entry, among: queue.entries(in: .parked)) {
            (retried.state, retried.attempts, retried.nextAttemptAt, retried.lastError) = (.pending, 0, nil, nil)
        }
        try context.save()
    }

    /// Gives up on a write and on the writes that depend on it. A discarded
    /// create takes its `local-` task with it, since no server copy will come;
    /// a discarded patch leaves its record, and the next refresh restores the
    /// server's copy once no write protects it (M3.5 spec, Decisions).
    /// A block's create takes its `local-` block, and so does a task's create
    /// that a block was placed on, through the block's dependent create (#201).
    public func discard(sequence: Int) throws {
        for discarded in queue.withdraw(try entry(sequence)) { try deleteRecord(createdBy: discarded) }
        try context.save()
    }

    private func deleteRecord(createdBy entry: OutboxEntry) throws {
        guard let localID = entry.createsLocalID else { return }
        if entry.kind == "block.create" {
            try context.delete(model: TimeBlockRecord.self, where: #Predicate { $0.id == localID })
        } else {
            try context.delete(model: TaskRecord.self, where: #Predicate { $0.id == localID })
        }
    }

    private func entry(_ sequence: Int) throws -> OutboxEntry {
        let descriptor = FetchDescriptor<OutboxEntry>(predicate: #Predicate { $0.sequence == sequence })
        guard let entry = try context.fetch(descriptor).first else { throw Failure.noEntry(sequence: sequence) }
        return entry
    }
}
