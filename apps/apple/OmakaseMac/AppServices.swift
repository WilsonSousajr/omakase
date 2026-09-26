import Foundation
import OmakaseAPI
import OmakaseStore
import SwiftData

/// Wires the packages together (spec, Structure: the app target stays thin).
/// Coordination - one catch-up at a time, signed-out surfaced, background work
/// started once - lives in OmakaseStore.SyncCoordinator, under the gate.
@MainActor
final class AppServices {
    let container: ModelContainer
    let api: OmakaseAPIClient
    let writes: TaskWrites
    let coordinator: SyncCoordinator
    private let reachability = Reachability()

    init() throws {
        container = try StoreSchema.container(inMemory: false)
        api = OmakaseAPIClient(baseURL: Self.baseURL, transport: URLSessionTransport(), tokens: KeychainTokenStore())
        let writes = TaskWrites(context: container.mainContext)
        self.writes = writes
        let sync = DaySync(context: container.mainContext, api: api)
        let worker = OutboxWorker(
            context: container.mainContext, api: api,
            handlers: OutboxHandlers([TaskHandler(context: container.mainContext)]))
        coordinator = SyncCoordinator(drain: { await worker.drain() }, refresh: { try await sync.refresh() })
    }

    var googleClientID: String { Bundle.main.object(forInfoDictionaryKey: "OmakaseGoogleClientID") as? String ?? "" }

    /// On launch, on reconnect and every 5 minutes; `onOutcome` sees every result.
    func startBackgroundCatchUp(onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void) {
        guard coordinator.claimBackgroundStart() else { return }
        let coordinator = self.coordinator
        reachability.start { Task { @MainActor in onOutcome(await coordinator.catchUp()) } }
        Task { @MainActor in
            while !Task.isCancelled {
                onOutcome(await coordinator.catchUp())
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    private static var baseURL: URL {
        let configured = Bundle.main.object(forInfoDictionaryKey: "OmakaseAPIBaseURL") as? String
        return configured.flatMap(URL.init(string:)) ?? URL(string: "http://localhost:8000")!
    }
}
