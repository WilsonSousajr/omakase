import Foundation
import OmakaseAPI
import SwiftData

/// A task's subtask; deleted with its task by DaySync. There is no SwiftData
/// relationship, so a subtask can arrive before its task's record exists.
@Model
public final class SubtaskRecord {
    @Attribute(.unique) public var id: String
    public var taskID: String
    public var title: String
    public var isCompleted: Bool
    public var order: Int

    public init(dto: SubtaskDTO, taskID: String) {
        (id, self.taskID) = (dto.id.uuidString, taskID)
        (title, isCompleted, order) = (dto.title, dto.isCompleted, dto.order)
    }

    public func apply(_ dto: SubtaskDTO) { (title, isCompleted, order) = (dto.title, dto.isCompleted, dto.order) }
}

/// A block on the day: session notes and rating are written here (M3.3).
@Model
public final class TimeBlockRecord {
    @Attribute(.unique) public var id: String
    public var day: String
    public var startTime: String
    public var endTime: String
    public var taskID: String?
    public var studyBlockID: String?
    public var notes: String
    public var sessionRating: Int?

    public init(dto: TimeBlockDTO) {
        id = dto.id.uuidString
        (day, startTime, endTime, notes, sessionRating) = ("", "", "", "", nil)
        apply(dto)
    }

    /// A block with no server copy yet: placed in Plan under a `local-` id (#201).
    public init(
        id: String, day: String, startTime: String, endTime: String, taskID: String? = nil,
        studyBlockID: String? = nil
    ) {
        (self.id, self.day, self.startTime, self.endTime) = (id, day, startTime, endTime)
        (self.taskID, self.studyBlockID, notes, sessionRating) = (taskID, studyBlockID, "", nil)
    }

    public func apply(_ dto: TimeBlockDTO) {
        (day, startTime, endTime) = (dto.date.string, dto.startTime, dto.endTime)
        (taskID, studyBlockID) = (dto.task?.uuidString, dto.studyBlock?.uuidString)
        (notes, sessionRating) = (dto.notes, dto.sessionRating)
    }
}

/// A study block scheduled for the day.
@Model
public final class StudyBlockRecord {
    @Attribute(.unique) public var id: String
    public var title: String
    public var disciplineID: String
    public var scheduledDay: String?
    public var isCompleted: Bool
    public var estimatedMinutes: Int?
    public var priority: String
    public var status: String

    public init(dto: StudyBlockDTO) {
        (id, title, disciplineID, priority, status) = (dto.id.uuidString, "", "", "", "")
        (isCompleted, scheduledDay, estimatedMinutes) = (false, nil, nil)
        apply(dto)
    }

    public func apply(_ dto: StudyBlockDTO) {
        (title, disciplineID, scheduledDay) = (dto.title, dto.discipline.uuidString, dto.scheduledDate?.string)
        (isCompleted, estimatedMinutes) = (dto.isCompleted, dto.estimatedMinutes)
        (priority, status) = (dto.priority, dto.status)
    }
}

/// The day's one review.
@Model
public final class DailyReviewRecord {
    @Attribute(.unique) public var day: String
    public var rating: Int?
    public var win: String
    public var energy: Int?
    public var isShutdown: Bool
    public var shutdownAt: Date?

    public init(day: String, rating: Int? = nil, win: String = "", energy: Int? = nil) {
        (self.day, self.rating, self.win, self.energy) = (day, rating, win, energy)
        (isShutdown, shutdownAt) = (false, nil)
    }

    public func apply(_ dto: DailyReviewDTO) {
        (rating, win, energy) = (dto.productivityRating, dto.winOfTheDay, dto.energy)
        (isShutdown, shutdownAt) = (dto.isShutdown, dto.shutdownAt)
    }

    /// The outbox subject for a day's review, which has no server id until it exists.
    public static func subjectID(for day: String) -> String { "review-\(day)" }
}

/// The user's pomodoro and goal settings: one row.
@Model
public final class ProfileRecord {
    @Attribute(.unique) public var key: String = "me"
    public var workMinutes: Int
    public var shortBreakMinutes: Int
    public var longBreakMinutes: Int
    public var beforeLongBreak: Int
    public var workGoalHours: Double
    public var studyGoalHours: Double
    // Defaulted to the server's defaults so older stores migrate (#127).
    public var blockReminderMinutes: Int? = 5
    /// "HH:MM:SS" in the user's day, nil for no shutdown reminder.
    public var shutdownReminderTime: String?
    /// The profile's IANA zone, shown in Settings; defaulted so older stores
    /// migrate (#224).
    public var timezone = "UTC"
    /// "monday" or "sunday": the first day of Plan's week.
    public var weekStartsOn = "monday"

    public init(dto: ProfileDTO) {
        (workMinutes, shortBreakMinutes, longBreakMinutes, beforeLongBreak) = (0, 0, 0, 0)
        (workGoalHours, studyGoalHours) = (0, 0)
        apply(dto)
    }

    public func apply(_ dto: ProfileDTO) {
        (workMinutes, shortBreakMinutes) = (dto.pomodoroWorkMinutes, dto.pomodoroShortBreakMinutes)
        (longBreakMinutes, beforeLongBreak) = (dto.pomodoroLongBreakMinutes, dto.pomodorosBeforeLongBreak)
        (workGoalHours, studyGoalHours) = (dto.workGoalHours, dto.studyGoalHours)
        (blockReminderMinutes, shutdownReminderTime) = (dto.blockReminderMinutes, dto.shutdownReminderTime)
        (timezone, weekStartsOn) = (dto.timezone, dto.weekStartsOn)
    }
}

/// The day's planned minutes against the goal, as the server last summed
/// them (#128): cached so the Focus header can warn offline.
@Model
public final class WorkloadRecord {
    @Attribute(.unique) public var day: String
    public var taskMinutes: Int = 0
    public var studyBlockMinutes: Int = 0
    public var classMinutes: Int = 0
    public var plannedMinutes: Int = 0
    public var goalMinutes: Int = 0
    public var overMinutes: Int = 0
    public var unestimatedCount: Int = 0

    public init(day: String) { self.day = day }

    public func apply(_ dto: WorkloadDTO) {
        (taskMinutes, studyBlockMinutes, classMinutes) = (dto.taskMinutes, dto.studyBlockMinutes, dto.classMinutes)
        (plannedMinutes, goalMinutes) = (dto.plannedMinutes, dto.goalMinutes)
        (overMinutes, unestimatedCount) = (dto.overMinutes, dto.unestimatedCount)
    }
}
