import Foundation

/// The pomodoro's rules as pure functions of `now`, so the timer is exact
/// after sleep or a quit and every rule is testable.
///
///     let running = PomodoroEngine.start(.idle, phase: .focus, taskID: id, blockID: nil, settings: s, now: .now)
public enum PomodoroEngine {
    public static func start(
        _ state: PomodoroState, phase: TimerPhase, taskID: String?, blockID: String?, settings: PomodoroSettings,
        now: Date
    ) -> PomodoroState {
        var next = state
        (next.phase, next.status, next.startedAt, next.pausedAt) = (phase, .running, now, nil)
        (next.pausedSeconds, next.plannedSeconds) = (0, settings.seconds(for: phase))
        (next.taskID, next.blockID) = (taskID, blockID)
        return next
    }

    public static func pause(_ state: PomodoroState, now: Date) -> PomodoroState {
        guard state.status == .running else { return state }
        var next = state
        (next.status, next.pausedAt) = (.paused, now)
        return next
    }

    public static func resume(_ state: PomodoroState, now: Date) -> PomodoroState {
        guard state.status == .paused, let pausedAt = state.pausedAt else { return state }
        var next = state
        (next.status, next.pausedAt) = (.running, nil)
        next.pausedSeconds += now.timeIntervalSince(pausedAt)
        return next
    }

    /// Time run in this phase, pauses excluded.
    public static func elapsed(_ state: PomodoroState, now: Date) -> TimeInterval {
        guard let startedAt = state.startedAt, state.status != .idle else { return 0 }
        let end = state.pausedAt ?? now
        return max(0, end.timeIntervalSince(startedAt) - state.pausedSeconds)
    }

    public static func remaining(_ state: PomodoroState, now: Date) -> TimeInterval {
        max(0, state.plannedSeconds - elapsed(state, now: now))
    }

    public static func progress(_ state: PomodoroState, now: Date) -> Double {
        state.plannedSeconds > 0 ? min(1, elapsed(state, now: now) / state.plannedSeconds) : 0
    }

    public static func isDue(_ state: PomodoroState, now: Date) -> Bool {
        state.status == .running && remaining(state, now: now) <= 0
    }

    /// The phase ran out: it is recorded as it ran (ending when it was due,
    /// however late this runs), and the next phase waits for a click.
    public static func finish(
        _ state: PomodoroState, now: Date, settings: PomodoroSettings
    ) -> (next: PomodoroState, done: CompletedPhase?) {
        guard let startedAt = state.startedAt, state.status != .idle else { return (state, nil) }
        let ended = startedAt.addingTimeInterval(state.plannedSeconds + state.pausedSeconds)
        let done = CompletedPhase(
            phase: state.phase, taskID: state.taskID, blockID: state.blockID, startedAt: startedAt,
            endedAt: min(ended, now), minutes: Int(state.plannedSeconds / 60), completed: true)
        return (waiting(after: state, completed: true, settings: settings), done)
    }

    /// The phase was cut short. Focus records its elapsed time as incomplete
    /// (IDEA.md: abandon logs the time), unless under a minute; a break
    /// records nothing.
    public static func skip(
        _ state: PomodoroState, now: Date, settings: PomodoroSettings
    ) -> (next: PomodoroState, done: CompletedPhase?) {
        let ran = elapsed(state, now: now)
        let next = waiting(after: state, completed: false, settings: settings)
        guard state.phase == .focus, ran >= 60, let startedAt = state.startedAt else { return (next, nil) }
        let done = CompletedPhase(
            phase: .focus, taskID: state.taskID, blockID: state.blockID, startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(ran + state.pausedSeconds), minutes: Int(ran / 60),
            completed: false)
        return (next, done)
    }

    /// The idle state for the phase after `state`.
    private static func waiting(
        after state: PomodoroState, completed: Bool, settings: PomodoroSettings
    ) -> PomodoroState {
        var next = state
        (next.status, next.startedAt, next.pausedAt, next.pausedSeconds) = (.idle, nil, nil, 0)
        switch (state.phase, completed) {
        case (.focus, true):
            next.completedFocuses += 1
            next.phase = next.completedFocuses % settings.beforeLongBreak == 0 ? .longBreak : .shortBreak
        case (.longBreak, true): (next.phase, next.completedFocuses) = (.focus, 0)
        default: next.phase = .focus
        }
        next.plannedSeconds = settings.seconds(for: next.phase)
        return next
    }
}
