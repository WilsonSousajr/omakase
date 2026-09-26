import Foundation
import OmakaseStore

/// How long each phase runs, from the synced profile.
public struct PomodoroSettings: Equatable, Sendable {
    public let workMinutes: Int
    public let shortBreakMinutes: Int
    public let longBreakMinutes: Int
    public let beforeLongBreak: Int

    public static let standard = PomodoroSettings(
        workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, beforeLongBreak: 4)

    public init(workMinutes: Int, shortBreakMinutes: Int, longBreakMinutes: Int, beforeLongBreak: Int) {
        (self.workMinutes, self.shortBreakMinutes) = (workMinutes, shortBreakMinutes)
        (self.longBreakMinutes, self.beforeLongBreak) = (longBreakMinutes, max(beforeLongBreak, 1))
    }

    /// The profile's durations, or the classic pomodoro before one has synced.
    @MainActor
    public init(profile: ProfileRecord?) {
        guard let profile else {
            self = .standard
            return
        }
        self.init(
            workMinutes: profile.workMinutes, shortBreakMinutes: profile.shortBreakMinutes,
            longBreakMinutes: profile.longBreakMinutes, beforeLongBreak: profile.beforeLongBreak)
    }

    func seconds(for phase: TimerPhase) -> TimeInterval {
        switch phase {
        case .focus: TimeInterval(workMinutes * 60)
        case .shortBreak: TimeInterval(shortBreakMinutes * 60)
        case .longBreak: TimeInterval(longBreakMinutes * 60)
        }
    }
}

/// The pomodoro as it stands: a value, persisted between launches. Nothing
/// ticks inside it; time is always read from `now` (PomodoroEngine).
public struct PomodoroState: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable {
        case idle
        case running
        case paused
    }

    public var phase: TimerPhase
    public var status: Status
    public var startedAt: Date?
    public var pausedAt: Date?
    public var pausedSeconds: TimeInterval
    public var plannedSeconds: TimeInterval
    public var taskID: String?
    public var blockID: String?
    public var completedFocuses: Int

    public static let idle = PomodoroState(
        phase: .focus, status: .idle, startedAt: nil, pausedAt: nil, pausedSeconds: 0,
        plannedSeconds: PomodoroSettings.standard.seconds(for: .focus), taskID: nil, blockID: nil, completedFocuses: 0)
}

/// What a phase runs on: the task, and its block today if it has one (#129).
public struct PomodoroTarget: Equatable, Sendable {
    public let taskID: String?
    public let blockID: String?

    public init(taskID: String?, blockID: String? = nil) { (self.taskID, self.blockID) = (taskID, blockID) }
}

/// A phase that ended and is recorded as a pomodoro session.
public struct CompletedPhase: Equatable, Sendable {
    public let phase: TimerPhase
    public let taskID: String?
    public let blockID: String?
    public let startedAt: Date
    public let endedAt: Date
    public let minutes: Int
    public let completed: Bool
}

extension TimerPhase {
    /// The server's `session_type` for this phase (backend/pomodoro/models.py).
    public var sessionType: String {
        switch self {
        case .focus: "focus"
        case .shortBreak: "short_break"
        case .longBreak: "long_break"
        }
    }
}
