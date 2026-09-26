import Foundation
import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// A named fake for the outbox's maintenance: serves a status the test sets,
/// records each retry, discard and sync, and can say an entry is already gone.
@MainActor
final class FakeOutboxMaintenance {
    var current = OutboxStatus(pendingCount: 0, parked: [], nextAttemptAt: nil)
    var missing: Set<Int> = []
    private(set) var retried: [Int] = []
    private(set) var discarded: [Int] = []
    private(set) var syncs = 0

    var actions: FailedWritesModel.Actions {
        FailedWritesModel.Actions(
            status: { [unowned self] in current },
            retry: { [unowned self] sequence in try settle(sequence) { retried.append($0) } },
            discard: { [unowned self] sequence in try settle(sequence) { discarded.append($0) } },
            syncNow: { [unowned self] in syncs += 1 })
    }

    /// Records the call, then drops the entry from the status, as the store would.
    private func settle(_ sequence: Int, record: (Int) -> Void) throws {
        guard !missing.contains(sequence) else { throw OutboxMaintenance.Failure.noEntry(sequence: sequence) }
        record(sequence)
        current = OutboxStatus(
            pendingCount: current.pendingCount, parked: current.parked.filter { $0.sequence != sequence },
            nextAttemptAt: nil)
    }
}

@MainActor
struct FailedWritesModelTests {
    let outbox = FakeOutboxMaintenance()

    func model(parked sequences: [Int] = [], pending: Int = 0) -> FailedWritesModel {
        outbox.current = OutboxStatus(
            pendingCount: pending, parked: sequences.map { SyncIndicatorTests.parked("task.patch", sequence: $0) },
            nextAttemptAt: nil)
        let model = FailedWritesModel(actions: outbox.actions)
        model.refresh()
        return model
    }

    @Test func refreshReadsTheOutbox() {
        let model = model(parked: [4, 7], pending: 1)
        #expect(model.parked.map(\.sequence) == [4, 7])
        #expect(model.indicator == .failed(2))
    }

    @Test func startsOnlineAndSynced() {
        #expect(model().indicator == .synced)
    }

    @Test func aPathThatDropsIsOffline() {
        let model = model(pending: 2)
        model.setPathOnline(false)
        #expect(model.indicator == .offline(queued: 2))
        model.setPathOnline(true)
        #expect(model.indicator == .queued(2))
    }

    @Test func aFailedCatchUpIsOfflineUntilOneSucceeds() {
        let model = model(pending: 1)
        model.record(.failed("could not connect to the server"))
        #expect(model.indicator == .offline(queued: 1))
        outbox.current = OutboxStatus(pendingCount: 0, parked: [], nextAttemptAt: nil)
        model.record(.synced)
        #expect(model.indicator == .synced)
    }

    @Test func aSignedOutCatchUpStillReachedTheServer() {
        let model = model()
        model.record(.failed("timed out"))
        model.record(.signedOut)
        #expect(model.indicator == .synced)
    }

    @Test func retrySendsTheWriteAndRefreshes() {
        let model = model(parked: [3])
        model.retry(model.parked[0])
        #expect(outbox.retried == [3])
        #expect(model.parked.isEmpty)
    }

    @Test func retryOfAWriteAlreadyGoneOnlyRefreshes() {
        let model = model(parked: [3])
        outbox.missing = [3]
        outbox.current = OutboxStatus(pendingCount: 0, parked: [], nextAttemptAt: nil)
        model.retry(SyncIndicatorTests.parked("task.patch", sequence: 3))
        #expect(outbox.retried.isEmpty)
        #expect(model.parked.isEmpty)
    }

    @Test func discardWaitsForConfirmation() {
        let model = model(parked: [5])
        model.askToDiscard(model.parked[0])
        #expect(model.discardCandidate?.sequence == 5)
        #expect(outbox.discarded.isEmpty)
        model.confirmDiscard()
        #expect(outbox.discarded == [5])
        #expect(model.discardCandidate == nil)
        #expect(model.parked.isEmpty)
    }

    @Test func cancellingADiscardKeepsTheWrite() {
        let model = model(parked: [5])
        model.askToDiscard(model.parked[0])
        model.cancelDiscard()
        model.confirmDiscard()
        #expect(outbox.discarded.isEmpty)
        #expect(model.parked.map(\.sequence) == [5])
    }

    @Test func discardOfAWriteAlreadyGoneOnlyRefreshes() {
        let model = model(parked: [5])
        outbox.missing = [5]
        model.askToDiscard(model.parked[0])
        outbox.current = OutboxStatus(pendingCount: 0, parked: [], nextAttemptAt: nil)
        model.confirmDiscard()
        #expect(outbox.discarded.isEmpty)
        #expect(model.parked.isEmpty)
        #expect(model.discardCandidate == nil)
    }

    @Test func syncNowAsksForACatchUp() {
        let model = model()
        model.syncNow()
        #expect(outbox.syncs == 1)
    }
}
