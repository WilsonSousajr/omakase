import Foundation
import OmakaseAPI
import OmakaseStore
import SwiftData

/// Wires the packages together (spec, Structure: the app target stays thin).
@MainActor
final class AppServices {
    let container: ModelContainer
    let api: OmakaseAPIClient
    let writes: TaskWrites
    private let sync: TodaySync
    private let worker: OutboxWorker
    private let reachability = Reachability()

    init() throws {
        container = try StoreSchema.container(inMemory: false)
        api = OmakaseAPIClient(baseURL: Self.baseURL, transport: URLSessionTransport(), tokens: KeychainTokenStore())
        let writes = TaskWrites(context: container.mainContext)
        self.writes = writes
        sync = TodaySync(context: container.mainContext, api: api)
        worker = OutboxWorker(context: container.mainContext, api: api) { writes.applyServerCopy($0, body: $1) }
    }

    var googleClientID: String { Bundle.main.object(forInfoDictionaryKey: "OmakaseGoogleClientID") as? String ?? "" }

    /// Drain queued writes, then refresh today - on launch, on reconnect, every 5 minutes.
    func catchUp() async {
        _ = await worker.drain()
        try? await sync.refresh()
    }

    func startBackgroundCatchUp() {
        reachability.start { Task { @MainActor in await self.catchUp() } }
        Task { @MainActor in
            while !Task.isCancelled {
                await catchUp()
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    private static var baseURL: URL {
        let configured = Bundle.main.object(forInfoDictionaryKey: "OmakaseAPIBaseURL") as? String
        return configured.flatMap(URL.init(string:)) ?? URL(string: "http://localhost:8000")!
    }
}
