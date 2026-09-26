import Foundation
import OmakaseAPI
import OmakaseFeatures
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
            handlers: Self.handlers(container.mainContext))
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

    /// Focus's writes, by task id: each finds the record, writes it through
    /// the outbox and catches up at once (#91); `onOutcome` sees the result.
    func focusActions(onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void) -> FocusModel.Actions {
        FocusModel.Actions(
            toggle: { [self] id in perform(on: id, onOutcome) { try self.writes.toggleCompletion($0) } },
            move: { [self] id, status in perform(on: id, onOutcome) { try self.writes.setKanbanStatus($0, to: status) }
            })
    }

    private func perform(
        on id: String, _ onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void,
        _ write: @escaping (TaskRecord) throws -> Void
    ) {
        let descriptor = FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try? container.mainContext.fetch(descriptor).first else { return }
        let coordinator = self.coordinator
        Task { onOutcome((try? await coordinator.write { try write(record) }) ?? .synced) }
    }

    /// Every kind of write the app queues, and what applies its reply (M3.1 spec §3).
    private static func handlers(_ context: ModelContext) -> OutboxHandlers {
        OutboxHandlers([
            TaskHandler(context: context), SubtaskHandler(context: context), BlockHandler(context: context),
            SessionHandler(), ReviewHandler(context: context),
        ])
    }

    private static var baseURL: URL {
        let configured = Bundle.main.object(forInfoDictionaryKey: "OmakaseAPIBaseURL") as? String
        return configured.flatMap(URL.init(string:)) ?? URL(string: "http://localhost:8000")!
    }
}
