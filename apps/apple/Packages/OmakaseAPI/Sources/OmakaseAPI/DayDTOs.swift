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

    public var workGoalHours: Double { Double(dailyWorkGoalHours) ?? 0 }
    public var studyGoalHours: Double { Double(dailyStudyGoalHours) ?? 0 }
}
