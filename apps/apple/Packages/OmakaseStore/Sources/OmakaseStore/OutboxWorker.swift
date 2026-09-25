import Foundation
import OmakaseAPI
import SwiftData

/// Replays queued writes one at a time, in order (spec, Data flow -> Replay).
///
///     let result = await OutboxWorker(context: ctx, api: api, onAccepted: apply).drain()
@MainActor
public final class OutboxWorker {
    public enum DrainResult: Equatable, Sendable {
        case empty
        case waiting(until: Date)
        case signedOut
    }

    private let context: ModelContext
    private let api: any APIClient
    private let clock: () -> Date
    private let onAccepted: (OutboxEntry, Data) -> Void
    /// The drain in progress, if any. A second caller awaits it rather than
    /// starting another: drain() suspends at send() with the entry still
    /// pending, so two drains would send it twice (review finding C2).
    private var running: Task<DrainResult, Never>?

    public init(
        context: ModelContext, api: any APIClient, clock: @escaping () -> Date = { .now },
        onAccepted: @escaping (OutboxEntry, Data) -> Void
    ) {
        (self.context, self.api, self.clock, self.onAccepted) = (context, api, clock, onAccepted)
    }

    /// Sends pending entries until the queue is empty, one must wait, or the user is signed out.
    /// Single-flight: concurrent callers share one drain.
    public func drain() async -> DrainResult {
        if let running { return await running.value }
        let task = Task { await drainOnce() }
        running = task
        defer { running = nil }
        return await task.value
    }

    private func drainOnce() async -> DrainResult {
        while let entry = pendingEntries().first {
            if let due = entry.nextAttemptAt, due > clock() { return .waiting(until: due) }
            if let stop = await attempt(entry) { return stop }
        }
        return .empty
    }

    private func attempt(_ entry: OutboxEntry) async -> DrainResult? {
        switch OutboxRules.classify(await send(entry)) {
        case .accepted(let body): accept(entry, body: body)
        case .park(let reason): park(entry, reason: reason)
        case .retry(let reason): return scheduleRetry(entry, reason: reason)
        case .signedOut: return .signedOut
        }
        try? context.save()
        return nil
    }

    private func send(_ entry: OutboxEntry) async -> Result<OutboxResponse, APIError> {
        let request = OutboxRequest(
            method: entry.method, path: entry.path, body: entry.body, idempotencyKey: entry.idempotencyKey)
        do {
            return .success(try await api.send(request))
        } catch {
            return .failure(error as? APIError ?? .transport("\(error)"))
        }
    }

    private func accept(_ entry: OutboxEntry, body: Data) {
        if let localID = entry.createsLocalID, let serverID = Self.serverID(in: body) {
            for pending in pendingEntries() { OutboxRules.rewrite(pending, localID: localID, serverID: serverID) }
        }
        onAccepted(entry, body)
        context.delete(entry)
    }

    private func park(_ entry: OutboxEntry, reason: String) {
        (entry.state, entry.lastError) = (.parked, reason)
        guard let localID = entry.createsLocalID else { return }
        for dependent in pendingEntries() where OutboxRules.references(dependent, localID: localID) {
            (dependent.state, dependent.lastError) = (.parked, "depends on a rejected create: \(reason)")
        }
    }

    private func scheduleRetry(_ entry: OutboxEntry, reason: String) -> DrainResult {
        entry.attempts += 1
        entry.lastError = reason
        let due = clock().addingTimeInterval(OutboxRules.backoff(afterAttempts: entry.attempts))
        entry.nextAttemptAt = due
        try? context.save()
        return .waiting(until: due)
    }

    private func pendingEntries() -> [OutboxEntry] {
        let pending = OutboxEntry.State.pending.rawValue
        let descriptor = FetchDescriptor<OutboxEntry>(
            predicate: #Predicate { $0.stateRaw == pending }, sortBy: [SortDescriptor(\.sequence)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func serverID(in body: Data) -> String? {
        let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        return object?["id"] as? String
    }
}
