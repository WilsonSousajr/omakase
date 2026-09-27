import Foundation

/// A subtask as `tasks/today/` embeds it (`SubtaskSerializer`).
public struct SubtaskDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let isCompleted: Bool
    public let order: Int
}

/// `TimeBlockSerializer`: exactly one of `task` and `studyBlock` is set.
/// Times are the server's `HH:MM:SS` wall-clock strings for `date`.
public struct TimeBlockDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let task: UUID?
    public let studyBlock: UUID?
    public let date: APIDay
    public let startTime: String
    public let endTime: String
    public let notes: String
    public let sessionRating: Int?
}

/// `StudyBlockSerializer`, the fields the day uses.
public struct StudyBlockDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let discipline: UUID
    public let title: String
    public let priority: String
    public let status: String
    public let estimatedMinutes: Int?
    public let scheduledDate: APIDay?
    public let isCompleted: Bool
}

/// `PomodoroSessionSerializer`: `startedAt` is the Mac's clock (M3.1 spec §1.1).
public struct PomodoroSessionDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let task: UUID?
    public let timeBlock: UUID?
    public let sessionType: String
    public let durationMinutes: Int
    public let startedAt: Date
    public let endedAt: Date?
    public let completed: Bool
}

/// `DailyReviewSerializer`: one per user and day.
public struct DailyReviewDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let date: APIDay
    public let productivityRating: Int?
    public let winOfTheDay: String
    public let energy: Int?
    public let isShutdown: Bool
    public let shutdownAt: Date?
}

/// `UserProfileSerializer`. The goal hours are `DecimalField`s, which DRF
/// sends as strings ("8.0"); the doubles are read from them (Review Focus 1).
public struct ProfileDTO: Sendable, Codable, Equatable {
    public let pomodoroWorkMinutes: Int
    public let pomodoroShortBreakMinutes: Int
    public let pomodoroLongBreakMinutes: Int
    public let pomodorosBeforeLongBreak: Int
    public let dailyWorkGoalHours: String
    public let dailyStudyGoalHours: String
    /// Minutes of heads-up before a time block starts, nil for none (#127).
    public let blockReminderMinutes: Int?
    /// The server's "HH:MM:SS" wall-clock time, nil for no shutdown reminder.
    public let shutdownReminderTime: String?

    public var workGoalHours: Double { Double(dailyWorkGoalHours) ?? 0 }
    public var studyGoalHours: Double { Double(dailyStudyGoalHours) ?? 0 }
}

/// `stats/workload/`: the day's planned minutes against the goal (#128).
/// `overMinutes` is `planned - goal`, negative while there is headroom.
public struct WorkloadDTO: Sendable, Codable, Equatable {
    public let date: APIDay
    public let taskMinutes: Int
    public let studyBlockMinutes: Int
    public let classMinutes: Int
    public let plannedMinutes: Int
    public let goalMinutes: Int
    public let overMinutes: Int
    public let unestimatedCount: Int
}

/// `ClassOccurrenceSerializer`: a weekly class on one date, computed by the
/// server and never written. `id` is "<class_schedule_id>-<date>", not a UUID.
/// A cancelled class is returned with `isCancelled`, not omitted (#125), and
/// `week` is its week of the semester's rotation, 1-based (#126).
public struct ClassOccurrenceDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let classScheduleId: UUID
    public let disciplineName: String
    public let disciplineColor: String
    public let classType: String
    public let location: String
    public let date: APIDay
    public let startTime: String
    public let endTime: String
    public let week: Int
    public let isCancelled: Bool
}
