/// The pomodoro as the now strip reads it: plain values, so the mapping is
/// testable without a running `TimerModel`.
public struct NowStripTimer: Equatable, Sendable {
    public let status: PomodoroState.Status
    public let phase: TimerPhase
    /// `MM:SS`, as `TimerModel.remainingText` reads.
    public let remaining: String
    /// 0...1, as `TimerModel.progress` reads.
    public let progress: Double
    public let taskID: String?
    /// The task's title, or nil when it isn't cached.
    public let title: String?

    public init(
        status: PomodoroState.Status, phase: TimerPhase, remaining: String, progress: Double, taskID: String?,
        title: String?
    ) {
        (self.status, self.phase, self.remaining, self.progress) = (status, phase, remaining, progress)
        (self.taskID, self.title) = (taskID, title)
    }

    /// The live timer, read once: the strip calls this on every tick, so
    /// only the strip observes `timer.now` (spec §6).
    ///
    ///     NowStripTimer(timer, title: tasks.first { $0.id == timer.state.taskID }?.title)
    @MainActor
    public init(_ timer: TimerModel, title: String?) {
        self.init(
            status: timer.state.status, phase: timer.state.phase, remaining: timer.remainingText,
            progress: timer.progress, taskID: timer.state.taskID, title: title)
    }
}

/// The day's next block as the strip reads it: when it starts, and its task.
public struct NowStripNext: Equatable, Sendable {
    /// `HH:MM:SS` as the store holds it; the strip shows `HH:MM`.
    public let start: String
    public let taskID: String?
    /// The task's title, or nil for a study block (or a task not cached).
    public let title: String?

    public init(start: String, taskID: String?, title: String?) {
        (self.start, self.taskID, self.title) = (start, taskID, title)
    }

    /// `MenuBar.nextBlock`'s slot, with its task's title.
    ///
    ///     MenuBar.nextBlock(in: slots, after: "13:20").map { NowStripNext(slot: $0, title: title(of: $0.taskID)) }
    public init(slot: SessionBlock.Slot, title: String?) {
        self.init(start: slot.start, taskID: slot.taskID, title: title)
    }
}

/// A phase on the strip: its ring's colour and fill, the countdown, and the
/// task it runs on.
public struct NowStripPhase: Equatable, Sendable {
    public let phase: TimerPhase
    public let remaining: String
    public let progress: Double
    public let title: String
    public let taskID: String?

    public init(phase: TimerPhase, remaining: String, progress: Double, title: String, taskID: String?) {
        (self.phase, self.remaining, self.progress, self.title, self.taskID) = (
            phase, remaining, progress, title, taskID
        )
    }
}

/// What the sidebar's now strip shows (spec §6).
public enum NowStripState: Equatable, Sendable {
    /// A phase runs: its ring, the countdown and its task.
    case running(NowStripPhase)
    /// The same, dimmed.
    case paused(NowStripPhase)
    /// Idle, with a block later today: "Next · 14:00 Title".
    case next(title: String, start: String, taskID: String?)
    /// Idle with nothing ahead: the strip shows nothing.
    case idle

    /// The task clicking the strip selects in Focus, or nil for none.
    public var taskID: String? {
        switch self {
        case .running(let phase), .paused(let phase): phase.taskID
        case .next(_, _, let taskID): taskID
        case .idle: nil
        }
    }
}

/// The now strip's mapping (spec §6, #260): the running or paused phase,
/// else the day's next block (`MenuBar.nextBlock`, as the menu-bar panel
/// picks it), else nothing. Its measures are `SidebarMetrics`'.
///
///     NowStrip.state(timer: NowStripTimer(timer, title: title), nextBlock: next)   // .running(…)
public enum NowStrip {
    /// A phase on, else the next block, else `.idle`. A phase whose task
    /// isn't cached reads as the phase ("Short break"); a block with no
    /// task is a study block, and reads "Study" as the menu-bar panel does.
    public static func state(timer: NowStripTimer, nextBlock: NowStripNext?) -> NowStripState {
        switch timer.status {
        case .running: .running(phase(of: timer))
        case .paused: .paused(phase(of: timer))
        case .idle: nextBlock.map(upcoming) ?? .idle
        }
    }

    private static func upcoming(_ next: NowStripNext) -> NowStripState {
        .next(title: next.title ?? "Study", start: String(next.start.prefix(5)), taskID: next.taskID)
    }

    private static func phase(of timer: NowStripTimer) -> NowStripPhase {
        NowStripPhase(
            phase: timer.phase, remaining: timer.remaining, progress: timer.progress,
            title: timer.title ?? timer.phase.title, taskID: timer.taskID)
    }
}
