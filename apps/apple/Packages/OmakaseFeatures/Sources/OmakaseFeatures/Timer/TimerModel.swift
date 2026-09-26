import Foundation
import Observation

/// The running pomodoro and its effects: saving the state (so it survives a
/// quit), recording a finished phase as a session, and the phase-end
/// notification. All injected, so the app wires them and tests record them.
///
///     let timer = TimerModel(state: saved, settings: { s }, blockFor: pick, actions: effects)
@Observable
@MainActor
public final class TimerModel {
    public struct Actions {
        let save: (PomodoroState) -> Void
        let record: (CompletedPhase) -> Void
        /// When the phase will end, or nil to cancel.
        let notify: (Date?, TimerPhase) -> Void

        public init(
            save: @escaping (PomodoroState) -> Void, record: @escaping (CompletedPhase) -> Void,
            notify: @escaping (Date?, TimerPhase) -> Void
        ) {
            (self.save, self.record, self.notify) = (save, record, notify)
        }
    }

    public private(set) var state: PomodoroState
    /// The focus that just ran out, for the end-of-focus prompt.
    public private(set) var lastFinished: CompletedPhase?
    /// Moves every second while the timer runs, so views re-read `now`.
    public private(set) var now: Date

    @ObservationIgnored private let settings: () -> PomodoroSettings
    @ObservationIgnored private let blockFor: (String) -> String?
    @ObservationIgnored private let actions: Actions
    @ObservationIgnored private let clock: () -> Date

    public init(
        state: PomodoroState, settings: @escaping () -> PomodoroSettings, blockFor: @escaping (String) -> String?,
        actions: Actions, clock: @escaping () -> Date = { .now }
    ) {
        (self.state, self.settings, self.blockFor, self.actions, self.clock) = (state, settings, blockFor, actions, clock)
        now = clock()
        // A timer that ran out while the app was quit is finished now, as it ran.
        tick()
    }

    /// Starts the waiting phase. Focus runs on `taskID` (and its block now);
    /// a break keeps the focus task.
    public func start(taskID: String?) {
        let now = clock()
        let task = state.phase == .focus ? taskID : state.taskID
        let block = task.flatMap(blockFor)
        update(PomodoroEngine.start(state, phase: state.phase, taskID: task, blockID: block, settings: settings(), now: now))
        actions.notify(now.addingTimeInterval(state.plannedSeconds), state.phase)
    }

    public func pause() {
        update(PomodoroEngine.pause(state, now: clock()))
        actions.notify(nil, state.phase)
    }

    public func resume() {
        let now = clock()
        update(PomodoroEngine.resume(state, now: now))
        actions.notify(now.addingTimeInterval(PomodoroEngine.remaining(state, now: now)), state.phase)
    }

    public func skip() {
        let (next, done) = PomodoroEngine.skip(state, now: clock(), settings: settings())
        actions.notify(nil, state.phase)
        done.map(actions.record)
        update(next)
    }

    /// Called every second: moves `now`, and ends the phase once it runs out.
    public func tick() {
        now = clock()
        guard PomodoroEngine.isDue(state, now: now) else { return }
        let (next, done) = PomodoroEngine.finish(state, now: now, settings: settings())
        done.map(actions.record)
        if let done, done.phase == .focus { lastFinished = done }
        update(next)
    }

    public func dismissFinished() { lastFinished = nil }

    public var remainingText: String {
        let seconds = Int(PomodoroEngine.remaining(state, now: now).rounded(.up))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    public var progress: Double { PomodoroEngine.progress(state, now: now) }

    private func update(_ next: PomodoroState) {
        state = next
        actions.save(next)
    }
}
