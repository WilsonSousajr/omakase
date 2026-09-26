import Foundation
import Observation
import OmakaseStore

/// The sync indicator's state and the failed-writes sheet's actions. The
/// outbox is injected, so the app wires `OutboxMaintenance` and a catch-up,
/// and tests use a fake.
///
/// The status is read again after every catch-up (`record`), reachability
/// change and user action, rather than observed live: every outbox change
/// ends in one of those, and the read is one small fetch.
///
///     let model = FailedWritesModel(actions: .init(status: { … }, retry: { … }, discard: { … }, syncNow: { … }))
///     coordinator.onEveryOutcome = { model.record($0) }
@Observable
@MainActor
public final class FailedWritesModel {
    /// The outbox, by entry sequence. `retry` and `discard` throw
    /// `OutboxMaintenance.Failure.noEntry` when the write is already gone.
    public struct Actions {
        let status: @MainActor () -> OutboxStatus
        let retry: @MainActor (Int) throws -> Void
        let discard: @MainActor (Int) throws -> Void
        let syncNow: @MainActor () -> Void

        public init(
            status: @escaping @MainActor () -> OutboxStatus, retry: @escaping @MainActor (Int) throws -> Void,
            discard: @escaping @MainActor (Int) throws -> Void, syncNow: @escaping @MainActor () -> Void
        ) { (self.status, self.retry, self.discard, self.syncNow) = (status, retry, discard, syncNow) }
    }

    public private(set) var status = OutboxStatus(pendingCount: 0, parked: [], nextAttemptAt: nil)
    /// The write the user asked to discard, until they confirm or cancel.
    public private(set) var discardCandidate: ParkedWrite?
    private var isPathOnline = true
    /// The last catch-up failed: the network is up but the server did not answer.
    private var isServerUnreachable = false

    @ObservationIgnored private let actions: Actions

    public init(actions: Actions) { self.actions = actions }

    public var parked: [ParkedWrite] { status.parked }

    public var indicator: SyncIndicator {
        SyncIndicator(isOnline: isPathOnline && !isServerUnreachable, status: status)
    }

    public func refresh() { status = actions.status() }

    public func setPathOnline(_ online: Bool) { isPathOnline = online }

    /// A catch-up's result: a failure means the server is out of reach; any
    /// answer, signed-out included, means it is back.
    public func record(_ outcome: SyncCoordinator.Outcome) {
        if case .failed = outcome { isServerUnreachable = true } else { isServerUnreachable = false }
        refresh()
    }

    /// A write the user sent or discarded elsewhere is gone (`noEntry`), so
    /// either way the list is read again.
    public func retry(_ write: ParkedWrite) {
        try? actions.retry(write.sequence)
        refresh()
    }

    public func askToDiscard(_ write: ParkedWrite) { discardCandidate = write }

    public func cancelDiscard() { discardCandidate = nil }

    /// Drops the user's change, once they have confirmed it.
    public func confirmDiscard() {
        guard let candidate = discardCandidate else { return }
        discardCandidate = nil
        try? actions.discard(candidate.sequence)
        refresh()
    }

    public func syncNow() { actions.syncNow() }
}
