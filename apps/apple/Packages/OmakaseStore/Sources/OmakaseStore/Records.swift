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

    public init(dto: TaskDTO) {
        id = dto.id.uuidString
        (title, priority, scheduledDay) = (dto.title, dto.priority, dto.scheduledDate?.string)
        (isCompleted, completedAt, updatedAt) = (dto.isCompleted, dto.completedAt, dto.updatedAt)
        (kanbanStatus, dueDay, estimatedMinutes) = (dto.kanbanStatus, dto.dueDate?.string, dto.estimatedMinutes)
    }

    /// A record with no server copy yet: a local capture, a preview, a test.
    public init(
        id: String, title: String, priority: String = "medium", scheduledDay: String? = nil, isCompleted: Bool = false
    ) {
        (self.id, self.title, self.priority, self.scheduledDay) = (id, title, priority, scheduledDay)
        (self.isCompleted, completedAt, updatedAt) = (isCompleted, nil, .now)
    }

    public func apply(_ dto: TaskDTO) {
        (title, priority, scheduledDay) = (dto.title, dto.priority, dto.scheduledDate?.string)
        (isCompleted, completedAt, updatedAt) = (dto.isCompleted, dto.completedAt, dto.updatedAt)
        (kanbanStatus, dueDay, estimatedMinutes) = (dto.kanbanStatus, dto.dueDate?.string, dto.estimatedMinutes)
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

    public var state: State {
        get { State(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }

    public init(
        sequence: Int, method: String, path: String, body: Data?, subjectID: String?,
        createsLocalID: String? = nil, now: Date = .now
    ) {
        (self.sequence, self.method, self.path, self.body) = (sequence, method, path, body)
        (self.subjectID, self.createsLocalID, createdAt) = (subjectID, createsLocalID, now)
        (idempotencyKey, attempts, stateRaw) = (UUID().uuidString, 0, State.pending.rawValue)
    }
}
