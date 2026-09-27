import Foundation

/// What the task editor changed (#218): nil leaves a field as it is. The
/// estimate and due date can also be cleared, which the server needs as an
/// explicit null, so they are `Clearable` rather than a double Optional.
///
///     TaskEdit(title: "Final essay", estimate: .clear)
public struct TaskEdit: Equatable, Sendable {
    public enum Clearable<Value: Equatable & Sendable>: Equatable, Sendable {
        case set(Value)
        case clear

        var value: Value? {
            guard case .set(let value) = self else { return nil }
            return value
        }
    }

    public var title: String?
    public var notes: String?
    public var priority: String?
    public var estimate: Clearable<Int>?
    public var dueDay: Clearable<String>?

    public init(
        title: String? = nil, notes: String? = nil, priority: String? = nil, estimate: Clearable<Int>? = nil,
        dueDay: Clearable<String>? = nil
    ) {
        (self.title, self.notes, self.priority) = (title, notes, priority)
        (self.estimate, self.dueDay) = (estimate, dueDay)
    }

    public var isEmpty: Bool { self == TaskEdit() }
}

/// An edit the server would refuse, caught before it is queued.
public enum TaskEditError: Error, Equatable, CustomStringConvertible {
    case blankTitle(String)

    public var description: String {
        switch self {
        case .blankTitle(let raw): "title \(raw.debugDescription) is blank; a task needs a non-blank title"
        }
    }
}

/// The PATCH body: only the changed keys, and an explicit null for a
/// cleared estimate or due date (a synthesized Encodable omits nil).
struct TaskEditBody: Encodable {
    let edit: TaskEdit

    enum CodingKeys: String, CodingKey {
        case title, description, priority, estimatedMinutes, dueDate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(edit.title, forKey: .title)
        try container.encodeIfPresent(edit.notes, forKey: .description)
        try container.encodeIfPresent(edit.priority, forKey: .priority)
        if let estimate = edit.estimate { try container.encode(estimate.value, forKey: .estimatedMinutes) }
        if let dueDay = edit.dueDay { try container.encode(dueDay.value, forKey: .dueDate) }
    }
}
