import Foundation
import OmakaseAPI
import Testing

@testable import OmakaseStore

/// Counts calls and returns a scripted result, for the coordinator's two steps.
@MainActor
final class FakeSteps {
    var drainResult: OutboxWorker.DrainResult = .empty
    var refreshError: APIError?
    private(set) var drains = 0
    private(set) var refreshes = 0

    func drain() async -> OutboxWorker.DrainResult {
        drains += 1
        return drainResult
    }

    func refresh() async throws {
        refreshes += 1
        if let refreshError { throw refreshError }
    }

    func coordinator() -> SyncCoordinator {
        SyncCoordinator(drain: { await self.drain() }, refresh: { try await self.refresh() })
    }

    func coordinator(wakes: FakeWakeScheduler) -> SyncCoordinator {
        SyncCoordinator(
            drain: { await self.drain() }, refresh: { try await self.refresh() },
            scheduleWake: { date, fire in wakes.schedule(date, fire) })
    }
}

/// Records each wake the coordinator asks for, and fires one on demand, so a
/// test never sleeps until a backoff ends.
@MainActor
final class FakeWakeScheduler {
    private(set) var scheduled: [Date] = []
    private(set) var cancelled: [Date] = []
    private var fires: [@MainActor () async -> Void] = []

    func schedule(_ date: Date, _ fire: @escaping @MainActor () async -> Void) -> SyncWake {
        scheduled.append(date)
        fires.append(fire)
        return SyncWake { self.cancelled.append(date) }
    }

    func fireLatest() async { await fires.last?() }
}

@MainActor
struct SyncCoordinatorTests {
    let steps = FakeSteps()

    @Test func drainsThenRefreshes() async {
        #expect(await steps.coordinator().catchUp() == .synced)
        #expect(steps.drains == 1 && steps.refreshes == 1)
    }

    @Test func aSignedOutQueueIsReportedAndSkipsTheRefresh() async {
        // Review finding I3: signed-out was discarded, so the app kept showing
        // stale data with a silently paused queue.
        steps.drainResult = .signedOut
        #expect(await steps.coordinator().catchUp() == .signedOut)
        #expect(steps.refreshes == 0)
    }

    @Test func aSignedOutRefreshIsReported() async {
        steps.refreshError = .signedOut
        #expect(await steps.coordinator().catchUp() == .signedOut)
    }

    @Test func anOfflineRefreshIsAFailureNotASignOut() async {
        steps.refreshError = .transport("offline")
        #expect(await steps.coordinator().catchUp() == .failed("offline"))
    }

    @Test func concurrentCatchUpsShareOneRun() async {
        let coordinator = steps.coordinator()
        async let first = coordinator.catchUp()
        async let second = coordinator.catchUp()
        _ = await (first, second)
        #expect(steps.drains == 1 && steps.refreshes == 1)
    }

    @Test func backgroundWorkStartsOnlyOnce() {
        // Review finding I4: .task runs per window, so each window added
        // another monitor and another 5-minute loop.
        let coordinator = steps.coordinator()
        #expect(coordinator.claimBackgroundStart())
        #expect(coordinator.claimBackgroundStart() == false)
    }

    @Test func aLocalWriteIsFollowedByACatchUpIssue91() async throws {
        // Smoke run: an online toggle sat in the outbox for up to 5 minutes,
        // because only launch, reconnect and the timer drained it.
        var wrote = false
        let outcome = try await steps.coordinator().write { wrote = true }
        #expect(wrote && outcome == .synced && steps.drains == 1)
    }

    @Test func aFailedLocalWriteDoesNotCatchUp() async {
        struct DiskFull: Error {}
        await #expect(throws: DiskFull.self) { try await steps.coordinator().write { throw DiskFull() } }
        #expect(steps.drains == 0)
    }

    @Test func aWaitingDrainWakesItselfOnceAtThatTime() async {
        // M3.5 spec: a write in backoff waited for the next reconnect, tick or write.
        let wakes = FakeWakeScheduler()
        let due = Date(timeIntervalSince1970: 1_772_884_830)
        steps.drainResult = .waiting(until: due)
        let coordinator = steps.coordinator(wakes: wakes)
        _ = await coordinator.catchUp()
        #expect(wakes.scheduled == [due])
        steps.drainResult = .empty
        await wakes.fireLatest()
        #expect(steps.drains == 2 && wakes.scheduled == [due] && wakes.cancelled.isEmpty)
    }

    @Test func aLaterEmptyCatchUpCancelsThePendingWake() async {
        let wakes = FakeWakeScheduler()
        let due = Date(timeIntervalSince1970: 1_772_884_830)
        steps.drainResult = .waiting(until: due)
        let coordinator = steps.coordinator(wakes: wakes)
        _ = await coordinator.catchUp()
        steps.drainResult = .empty
        _ = await coordinator.catchUp()
        #expect(wakes.cancelled == [due])
    }

    @Test func twoWaitingsKeepOnlyTheLatestWake() async {
        let wakes = FakeWakeScheduler()
        let first = Date(timeIntervalSince1970: 1_772_884_801)
        let second = Date(timeIntervalSince1970: 1_772_884_802)
        let coordinator = steps.coordinator(wakes: wakes)
        steps.drainResult = .waiting(until: first)
        _ = await coordinator.catchUp()
        steps.drainResult = .waiting(until: second)
        _ = await coordinator.catchUp()
        #expect(wakes.scheduled == [first, second] && wakes.cancelled == [first])
    }

    @Test func everyRunIsReportedOnceTheBackoffWakeIncludedIssue185() async {
        // The wake's outcome was dropped, so the toolbar said Offline until
        // the next 5-minute tick after the server came back.
        let wakes = FakeWakeScheduler()
        var reported: [SyncCoordinator.Outcome] = []
        let coordinator = steps.coordinator(wakes: wakes)
        coordinator.onEveryOutcome = { reported.append($0) }
        steps.drainResult = .waiting(until: Date(timeIntervalSince1970: 1_772_884_830))
        steps.refreshError = .transport("offline")
        async let first = coordinator.catchUp()
        async let shared = coordinator.catchUp()
        _ = await (first, shared)
        (steps.drainResult, steps.refreshError) = (.empty, nil)
        await wakes.fireLatest()
        #expect(reported == [.failed("offline"), .synced])
    }
}

@MainActor
struct SyncWakeTests {
    @Test func aSleepingWakeFiresAtItsTime() async {
        await withCheckedContinuation { (resumed: CheckedContinuation<Void, Never>) in
            _ = SyncWake.sleeping(until: .now.addingTimeInterval(0.01)) { resumed.resume() }
        }
    }

    @Test func aCancelledSleepingWakeNeverFires() async throws {
        var fired = false
        SyncWake.sleeping(until: .now.addingTimeInterval(0.05)) { fired = true }.cancel()
        try await Task.sleep(for: .milliseconds(200))
        #expect(fired == false)
    }
}
