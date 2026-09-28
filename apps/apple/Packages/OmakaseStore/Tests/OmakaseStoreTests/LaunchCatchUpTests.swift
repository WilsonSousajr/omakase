import Foundation
import OmakaseAPI
import Testing

@testable import OmakaseStore

/// #276: a launch catch-up used to report `.failed` for an already-expired
/// access token, because each of `DaySync`'s seven concurrent reads
/// refreshed on its own and only one was ever retried. `FakeAPIClient`
/// (used by `DaySyncTests`/`SyncCoordinatorTests`) never produces a 401, so
/// it can't see this: this test wires a real `OmakaseAPIClient` through a
/// real `DaySync` and `SyncCoordinator` instead, to pin the user-visible
/// symptom, not just the client's own refresh count.
@MainActor
struct LaunchCatchUpTests {
    @Test func aLaunchCatchUpWithAnExpiredTokenReportsSuccessIssue276() async throws {
        let container = try StoreSchema.container(inMemory: true)
        let transport = ExpiredLaunchTokenTransport()
        let tokens = InMemoryTokenStore(StoredTokens(access: "expired", refresh: "r1"))
        let api = OmakaseAPIClient(baseURL: URL(string: "http://localhost:8000")!, transport: transport, tokens: tokens)
        let day = DaySync(
            context: container.mainContext, api: api, clock: { Date(timeIntervalSince1970: 1_772_884_800) })
        let coordinator = SyncCoordinator(drain: { .empty }, refresh: { try await day.refresh() })
        let outcome = await coordinator.catchUp()
        #expect(outcome == .synced)
        #expect(await transport.refreshCount == 1)
    }
}
