import Foundation
import OmakaseAPI
import SwiftData

/// A weekly class on one day, as the server computed it. Never draggable (M4
/// spec, Decisions); the one local write is its cancellation (#207).
@Model
public final class ClassOccurrenceRecord {
    /// "<class_schedule_id>-<date>", the server's id for the occurrence.
    @Attribute(.unique) public var id: String
    public var classScheduleID: String
    public var day: String
    /// The server's "HH:MM:SS" wall-clock strings for `day`.
    public var startTime: String
    public var endTime: String
    public var disciplineName: String
    public var disciplineColor: String
    public var classType: String
    public var location: String
    /// Week of the semester's rotation, 1-based (#126).
    public var week: Int = 1
    /// Cancelled on this date: still drawn, struck through (#125, #207).
    public var isCancelled: Bool = false

    public init(dto: ClassOccurrenceDTO) {
        (id, classScheduleID, day, startTime, endTime) = (dto.id, "", "", "", "")
        (disciplineName, disciplineColor, classType, location) = ("", "", "", "")
        apply(dto)
    }

    public func apply(_ dto: ClassOccurrenceDTO) {
        (classScheduleID, day) = (dto.classScheduleId.uuidString, dto.date.string)
        (startTime, endTime) = (dto.startTime, dto.endTime)
        (disciplineName, disciplineColor) = (dto.disciplineName, dto.disciplineColor)
        (classType, location) = (dto.classType, dto.location)
        (week, isCancelled) = (dto.week, dto.isCancelled)
    }
}

/// A pomodoro session as the server recorded it, drawn at its real time on
/// Plan (R8). Read-only: the Mac posts sessions through the outbox and reads
/// them back here.
@Model
public final class SessionRecord {
    @Attribute(.unique) public var id: String
    public var taskID: String?
    public var timeBlockID: String?
    public var sessionType: String
    public var startedAt: Date
    public var endedAt: Date?
    public var durationMinutes: Int
    public var completed: Bool

    public init(dto: PomodoroSessionDTO) {
        (id, sessionType, startedAt, durationMinutes, completed) = (dto.id.uuidString, "", dto.startedAt, 0, false)
        apply(dto)
    }

    public func apply(_ dto: PomodoroSessionDTO) {
        (taskID, timeBlockID) = (dto.task?.uuidString, dto.timeBlock?.uuidString)
        (sessionType, durationMinutes, completed) = (dto.sessionType, dto.durationMinutes, dto.completed)
        (startedAt, endedAt) = (dto.startedAt, dto.endedAt)
    }
}
