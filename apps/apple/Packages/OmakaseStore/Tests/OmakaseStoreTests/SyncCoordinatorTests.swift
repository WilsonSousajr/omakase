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
}
