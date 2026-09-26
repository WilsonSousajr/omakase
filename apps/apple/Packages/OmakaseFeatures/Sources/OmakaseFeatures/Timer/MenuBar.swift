/// What the menu-bar extra shows (spec, Menu bar).
///
///     MenuBar.label(for: timer.state, remaining: timer.remainingText)   // "18:42"
public enum MenuBar {
    /// The countdown while a phase is on (marked when paused); nil when idle,
    /// so the status item shows only its icon.
    public static func label(for state: PomodoroState, remaining: String) -> String? {
        switch state.status {
        case .idle: nil
        case .running: remaining
        case .paused: "\(remaining) ⏸"
        }
    }

    /// The first block that starts after `time` (`HH:MM`).
    public static func nextBlock(in slots: [SessionBlock.Slot], after time: String) -> SessionBlock.Slot? {
        slots.filter { $0.start.prefix(5) > time }.min { $0.start < $1.start }
    }
}

/// The notification when a phase runs out. The next phase waits for a click
/// (decided with the user), so it suggests rather than announces.
public struct PhaseNotice: Equatable, Sendable {
    public let title: String
    public let body: String

    public static func ending(_ phase: TimerPhase) -> PhaseNotice {
        switch phase {
        case .focus: PhaseNotice(title: "Focus done", body: "Time for a break.")
        case .shortBreak, .longBreak: PhaseNotice(title: "Break over", body: "Ready to focus?")
        }
    }
}
