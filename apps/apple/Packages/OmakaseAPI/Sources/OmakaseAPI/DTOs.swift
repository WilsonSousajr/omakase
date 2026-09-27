import Foundation

/// A DRF page (`PAGE_SIZE` 50): follow `next` until it is nil.
public struct Page<Item: Sendable & Codable & Equatable>: Sendable, Codable, Equatable {
    public let count: Int
    public let next: URL?
    public let previous: URL?
    public let results: [Item]
}

/// `TaskListSerializer` (backend/tasks/serializers.py); `tag_ids` is write-only.
/// `id` is nil only for a series' computed occurrence (`isVirtual`, #124),
/// which is known by its `series` and `occurrenceDate` instead.
public struct TaskDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID?
    public let title: String
    public let description: String
    public let priority: String
    public let area: String
    public let kanbanStatus: String
    public let project: UUID?
    public let discipline: UUID?
    public let tags: [TagDTO]
    public let scheduledDate: APIDay?
    public let dueDate: APIDay?
    public let estimatedMinutes: Int?
    public let actualMinutes: Int
    public let kanbanOrder: Int
    public let isCompleted: Bool
    public let completedAt: Date?
    /// When to remind about the task, or nil for no reminder (#127).
    public let remindAt: Date?
    public let createdAt: Date
    public let updatedAt: Date
    /// Embedded by today and carried-over only; nil elsewhere, and then sync leaves local subtasks alone.
    public let subtasks: [SubtaskDTO]?
    /// The series template this task is an occurrence of, or nil.
    public let series: UUID?
    /// The rule date this occurrence stands for; its `scheduledDate` may differ once moved.
    public let occurrenceDate: APIDay?
    public let isSkipped: Bool
    /// Computed by the server and not stored: `id` is nil until it is materialized.
    public let isVirtual: Bool
    /// The series' rule, or nil outside a series.
    public let recurrence: RecurrenceDTO?
}

/// `TaskRecurrenceSerializer`: `weekdays` are 0 (Monday) to 6, for a weekly
/// rule only; empty means the weekday of `startsOn`. `until` is inclusive.
public struct RecurrenceDTO: Sendable, Codable, Equatable {
    public let freq: String
    public let interval: Int
    public let weekdays: [Int]
    public let startsOn: APIDay
    public let until: APIDay?

    public init(freq: String, interval: Int, weekdays: [Int], startsOn: APIDay, until: APIDay?) {
        (self.freq, self.interval, self.weekdays, self.startsOn, self.until) = (
            freq, interval, weekdays, startsOn, until
        )
    }
}

public struct TagDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let color: String
    public let area: String
    public let createdAt: Date
}

public struct UserDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: Int
    public let username: String
    public let email: String
    public let firstName: String
    public let lastName: String
    public let avatarColor: String
    public let dateJoined: Date
}

/// `POST auth/google/`: the JWT pair and the signed-in user.
public struct TokenPairDTO: Sendable, Codable, Equatable {
    public let access: String
    public let refresh: String
    public let user: UserDTO
}

/// `POST auth/token/refresh/`: refresh tokens are not rotated.
public struct AccessTokenDTO: Sendable, Codable, Equatable {
    public let access: String
}
