import Foundation

/// A task's kind (spec §1). Life is the wire value `personal`; an unknown
/// wire value reads as Work.
public enum TaskArea: String, CaseIterable, Sendable {
    case work
    case study
    case life = "personal"

    public init(wire: String) {
        self = TaskArea(rawValue: wire) ?? .work
    }
}

/// A task's optional parent: a project files it under Work, a discipline
/// under Study. Ids are the server UUID strings as the store keeps them.
public enum TaskParent: Hashable, Sendable {
    case project(String)
    case discipline(String)
}

/// A task's kind and parent together, so the store always sends a
/// consistent body (spec §1): screens and sync read the kind from here
/// rather than deriving it themselves.
public struct TaskFiling: Hashable, Sendable {
    public let area: TaskArea
    public let parent: TaskParent?

    /// The only place the kind is derived: a discipline means Study, a
    /// project means Work, and with no parent the given area stands.
    ///
    ///     TaskFiling(area: .work, parent: .discipline("d1")).area == .study
    public init(area: TaskArea, parent: TaskParent?) {
        self.parent = parent
        switch parent {
        case .discipline: self.area = .study
        case .project: self.area = .work
        case nil: self.area = area
        }
    }

    /// Builds the parent from the server's two ids, then derives through
    /// `init(area:parent:)`. A discipline wins when both are set, which also
    /// covers an inconsistent server row (area "work" with a discipline).
    public init(areaWire: String, projectID: String?, disciplineID: String?) {
        let parent: TaskParent? =
            disciplineID.map(TaskParent.discipline) ?? projectID.map(TaskParent.project)
        self.init(area: TaskArea(wire: areaWire), parent: parent)
    }
}

extension TaskParent {
    /// The id to send as `project`, or nil when this parent is a discipline or absent.
    var projectID: String? {
        guard case .project(let id) = self else { return nil }
        return id
    }

    /// The id to send as `discipline`, or nil when this parent is a project or absent.
    var disciplineID: String? {
        guard case .discipline(let id) = self else { return nil }
        return id
    }
}
