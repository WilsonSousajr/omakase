import Foundation

/// A DRF page (`PAGE_SIZE` 50): follow `next` until it is nil.
public struct Page<Item: Sendable & Codable & Equatable>: Sendable, Codable, Equatable {
    public let count: Int
    public let next: URL?
    public let previous: URL?
    public let results: [Item]
}

/// `TaskListSerializer` (backend/tasks/serializers.py); `tag_ids` is write-only.
public struct TaskDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
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
    public let createdAt: Date
    public let updatedAt: Date
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
