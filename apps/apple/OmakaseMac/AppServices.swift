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
            },
            reschedule: { [self] id, day in perform(on: id, onOutcome) { try self.writes.reschedule($0, to: day) } },
            toggleSubtask: { [self] id in toggleSubtask(id, onOutcome) })
    }

    private func toggleSubtask(_ id: String, _ onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void) {
        let descriptor = FetchDescriptor<SubtaskRecord>(predicate: #Predicate { $0.id == id })
        guard let subtask = try? container.mainContext.fetch(descriptor).first else { return }
        let (coordinator, writes) = (self.coordinator, SubtaskWrites(context: container.mainContext))
        Task { onOutcome((try? await coordinator.write { try writes.toggle(subtask) }) ?? .synced) }
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

    /// The pomodoro, resumed from the store: a phase that ran out while the
    /// app was quit is recorded as it ran. Its finished phases are posted as
    /// sessions through the outbox, against the task's block (#129).
    func makeTimer(onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void) -> TimerModel {
        let context = container.mainContext
        let store = TimerStateStore(context: context)
        let saved = store.load().flatMap { try? JSONDecoder().decode(PomodoroState.self, from: $0) } ?? .idle
        return TimerModel(
            state: saved,
            settings: { PomodoroSettings(profile: try? context.fetch(FetchDescriptor<ProfileRecord>()).first) },
            blockFor: { [self] in blockNow(for: $0) },
            actions: TimerModel.Actions(
                save: { try? store.save(JSONEncoder().encode($0)) },
                record: { [self] in record($0, onOutcome) },
                notify: { _, _ in }))
    }

    private func blockNow(for taskID: String) -> String? {
        let day = FocusDay().today
        let descriptor = FetchDescriptor<TimeBlockRecord>(predicate: #Predicate { $0.day == day })
        let blocks = (try? container.mainContext.fetch(descriptor)) ?? []
        let slots = blocks.map { SessionBlock.Slot(id: $0.id, taskID: $0.taskID, start: $0.startTime, end: $0.endTime) }
        let now = Calendar.current.dateComponents([.hour, .minute], from: .now)
        return SessionBlock.pick(
            for: taskID, in: slots, at: String(format: "%02d:%02d", now.hour ?? 0, now.minute ?? 0))
    }

    private func record(_ phase: CompletedPhase, _ onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void) {
        let context = container.mainContext
        let task = phase.taskID.flatMap { id in
            try? context.fetch(FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == id })).first
        }
        let session = FinishedSession(
            timeBlockID: phase.blockID, type: phase.phase.sessionType, minutes: phase.minutes,
            startedAt: phase.startedAt, endedAt: phase.endedAt, completed: phase.completed)
        let (coordinator, writes) = (self.coordinator, SessionWrites(context: context))
        Task { onOutcome((try? await coordinator.write { try writes.record(session, task: task) }) ?? .synced) }
    }

    /// The prompt for a focus that just finished: its task's title and the
    /// subtasks it has checked (#163).
    func prompt(for finished: CompletedPhase?) -> SessionPrompt? {
        guard let taskID = finished?.taskID else { return nil }
        let context = container.mainContext
        let task = try? context.fetch(FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == taskID })).first
        let done = FetchDescriptor<SubtaskRecord>(
            predicate: #Predicate { $0.taskID == taskID && $0.isCompleted }, sortBy: [SortDescriptor(\.order)])
        let subtasks = (try? context.fetch(done)) ?? []
        return SessionPrompt.make(for: finished, taskTitle: task?.title, doneSubtasks: subtasks.map(\.title))
    }

    /// Saves the prompt's rating and notes to the block, through the outbox.
    func apply(_ writes: [SessionPrompt.Write], onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void) {
        let context = container.mainContext
        let (coordinator, blocks) = (self.coordinator, BlockWrites(context: context))
        func block(_ id: String) -> TimeBlockRecord? {
            try? context.fetch(FetchDescriptor<TimeBlockRecord>(predicate: #Predicate { $0.id == id })).first
        }
        Task {
            let outcome = try? await coordinator.write {
                for write in writes {
                    switch write {
                    case .rate(let id, let value): if let found = block(id) { try blocks.rate(found, value) }
                    case .notes(let id, let text): if let found = block(id) { try blocks.saveNotes(found, text) }
                    }
                }
            }
            onOutcome(outcome ?? .synced)
        }
    }

    /// Ticks the timer every second while the app runs, so a phase ends on
    /// time with the window closed (the menu bar and notifications rely on it).
    func startTicking(_ timer: TimerModel) {
        Task { @MainActor in
            while !Task.isCancelled {
                timer.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
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
