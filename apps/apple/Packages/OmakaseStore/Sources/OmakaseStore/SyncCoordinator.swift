import Foundation
import OmakaseAPI

/// One catch-up at a time: drain the outbox, then refresh, and say whether the
/// user is still signed in. Lives here, under the coverage gate, rather than in
/// the app target (final review, findings C2, I3, I4).
///
///     if await coordinator.catchUp() == .signedOut { showSignIn() }
@MainActor
public final class SyncCoordinator {
    public enum Outcome: Equatable, Sendable {
        case synced
        case signedOut
        case failed(String)
    }

    private let drain: () async -> OutboxWorker.DrainResult
    private let refresh: () async throws -> Void
    private var running: Task<Outcome, Never>?
    private var backgroundStarted = false
    private let scheduleWake: SyncWakeScheduler
    /// The catch-up booked for when the current backoff ends; at most one.
    private var pendingWake: SyncWake?
    /// Sees each run's outcome once, whoever started it: a caller, a shared
    /// run, or the backoff wake, whose outcome has no caller (#185).
    public var onEveryOutcome: (@MainActor (Outcome) -> Void)?

    /// `scheduleWake` books the catch-up that ends a backoff; the default sleeps in a task.
    public init(
        drain: @escaping () async -> OutboxWorker.DrainResult, refresh: @escaping () async throws -> Void,
        scheduleWake: @escaping SyncWakeScheduler = { date, fire in SyncWake.sleeping(until: date, fire: fire) }
    ) {
        (self.drain, self.refresh, self.scheduleWake) = (drain, refresh, scheduleWake)
    }

    /// Concurrent callers share one run.
    public func catchUp() async -> Outcome {
        if let running { return await running.value }
        let task = Task {
            let outcome = await runOnce()
            onEveryOutcome?(outcome)
            return outcome
        }
        running = task
        defer { running = nil }
        return await task.value
    }

    /// Performs a local write, then catches up at once, so an online change
    /// reaches the server now rather than at the next 5-minute tick (#91).
    /// A write that throws is not followed by a catch-up.
    ///
    ///     try await coordinator.write { try writes.toggleCompletion(record) }
    @discardableResult
    public func write(_ perform: () throws -> Void) async throws -> Outcome {
        try perform()
        return await catchUp()
    }

    /// True the first time only: background work (reachability, the timer) starts once per process.
    public func claimBackgroundStart() -> Bool {
        defer { backgroundStarted = true }
        return !backgroundStarted
    }

    private func runOnce() async -> Outcome {
        let drained = await drain()
        rescheduleWake(after: drained)
        guard drained != .signedOut else { return .signedOut }
        do {
            try await refresh()
            return .synced
        } catch APIError.signedOut {
            return .signedOut
        } catch APIError.transport(let reason) {
            return .failed(reason)
        } catch {
            return .failed(String(describing: error))
        }
    }

    /// A write in backoff is retried when the backoff ends, not at the next
    /// reconnect, tick or write (M3.5 spec). Any other result makes the
    /// booked wake stale.
    private func rescheduleWake(after drained: OutboxWorker.DrainResult) {
        pendingWake?.cancel()
        pendingWake = nil
        guard case .waiting(let due) = drained else { return }
        pendingWake = scheduleWake(due) { [weak self] in
            self?.pendingWake = nil
            _ = await self?.catchUp()
        }
    }
}
