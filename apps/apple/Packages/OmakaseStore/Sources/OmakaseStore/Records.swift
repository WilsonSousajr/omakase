import Foundation
import OmakaseAPI
import SwiftData

/// A task as the UI sees it: the server's copy, or a local one with queued writes.
@Model
public final class TaskRecord {
    @Attribute(.unique) public var id: String
    public var title: String
    public var priority: String
    public var scheduledDay: String?
    public var isCompleted: Bool
    public var completedAt: Date?
    public var updatedAt: Date
    // Defaulted so SwiftData migrates M1/M2 stores without a hand-written migration.
    public var kanbanStatus: String = "todo"
    public var dueDay: String?
    public var estimatedMinutes: Int?
    /// Scheduled before today and not done: shown apart in Focus (#129).
    public var isCarriedOver: Bool = false
    /// When to remind about the task (#127); nil means no reminder.
    public var remindAt: Date?
    /// The server's `description`, edited in the task editor (#218). Not
    /// `description`, which reads as CustomStringConvertible's.
    public var notes: String = ""
    /// The series this task is an occurrence of (#206), or nil for a one-off task.
    public var seriesID: String?
    /// The rule date the occurrence stands for, apart from where it is scheduled.
    public var occurrenceDay: String?
    /// Computed by the server and never stored there: the first write
    /// materializes it (`TaskWrites`), and until then its id is `occ-…`.
    public var isVirtual: Bool = false
    // Defaulted so SwiftData migrates pre-M9 stores without a hand-written
    // migration, as kanbanStatus did (spec §1).
    public var area: String = "work"
    public var projectID: String?
    public var disciplineID: String?

    /// Part of a repeating series: Focus and Plan mark it with a repeat glyph.
    public var isRepeating: Bool { seriesID != nil }

    /// This task's kind and parent, derived from `area`, `projectID` and
    /// `disciplineID` the same way everywhere (`TaskFiling.init(areaWire:projectID:disciplineID:)`).
    public var filing: TaskFiling {
        TaskFiling(areaWire: area, projectID: projectID, disciplineID: disciplineID)
    }

    public init(dto: TaskDTO) {
        id = dto.recordID
        (title, priority, scheduledDay) = (dto.title, dto.priority, dto.scheduledDate?.string)
        (isCompleted, completedAt, updatedAt) = (dto.isCompleted, dto.completedAt, dto.updatedAt)
        (kanbanStatus, dueDay, estimatedMinutes) = (dto.kanbanStatus, dto.dueDate?.string, dto.estimatedMinutes)
        (remindAt, notes) = (dto.remindAt, dto.description)
        (seriesID, occurrenceDay, isVirtual) = (dto.series?.uuidString, dto.occurrenceDate?.string, dto.isVirtual)
        (area, projectID, disciplineID) = (dto.area, dto.project?.uuidString, dto.discipline?.uuidString)
    }

    /// A record with no server copy yet: a local capture, a preview, a test.
    public init(
        id: String, title: String, priority: String = "medium", scheduledDay: String? = nil, isCompleted: Bool = false,
        filing: TaskFiling = TaskFiling(area: .work, parent: nil)
    ) {
        (self.id, self.title, self.priority, self.scheduledDay) = (id, title, priority, scheduledDay)
        (self.isCompleted, completedAt, updatedAt) = (isCompleted, nil, .now)
        (area, projectID, disciplineID) = (filing.area.rawValue, filing.parent?.projectID, filing.parent?.disciplineID)
    }

    public func apply(_ dto: TaskDTO) {
        (title, priority, scheduledDay) = (dto.title, dto.priority, dto.scheduledDate?.string)
        (isCompleted, completedAt, updatedAt) = (dto.isCompleted, dto.completedAt, dto.updatedAt)
        (kanbanStatus, dueDay, estimatedMinutes) = (dto.kanbanStatus, dto.dueDate?.string, dto.estimatedMinutes)
        (remindAt, notes) = (dto.remindAt, dto.description)
        (seriesID, occurrenceDay, isVirtual) = (dto.series?.uuidString, dto.occurrenceDate?.string, dto.isVirtual)
        (area, projectID, disciplineID) = (dto.area, dto.project?.uuidString, dto.discipline?.uuidString)
    }
}

/// One queued write (spec, Data flow -> Writes). Sent in `sequence` order.
@Model
public final class OutboxEntry {
    public enum State: String, Codable, Sendable {
        case pending
        case parked
    }

    @Attribute(.unique) public var sequence: Int
    public var method: String
    public var path: String
    public var body: Data?
    public var idempotencyKey: String
    /// The id of the item this write concerns, which read sync must not overwrite.
    public var subjectID: String?
    /// The `local-` id this entry creates, rewritten once the server answers.
    public var createsLocalID: String?
    public var createdAt: Date
    public var attempts: Int
    public var nextAttemptAt: Date?
    public var lastError: String?
    public var stateRaw: String
    /// Which OutboxHandler applies the reply. The default keeps M1's queued entries valid (M3.1 spec §3).
    public var kind: String = "task.patch"

    public var state: State {
        get { State(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }

    public init(
        sequence: Int, method: String, path: String, body: Data?, subjectID: String?,
        createsLocalID: String? = nil, kind: String = "task.patch", now: Date = .now
    ) {
        (self.sequence, self.method, self.path, self.body, self.kind) = (sequence, method, path, body, kind)
        (self.subjectID, self.createsLocalID, createdAt) = (subjectID, createsLocalID, now)
        (idempotencyKey, attempts, stateRaw) = (UUID().uuidString, 0, State.pending.rawValue)
    }
}
