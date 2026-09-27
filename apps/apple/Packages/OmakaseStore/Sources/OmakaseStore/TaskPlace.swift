import Foundation
import SwiftData

/// A place a task can be filed: a project, a discipline, or Life (spec §3, §5).
public enum TaskPlace: Hashable, Sendable {
    case project(String)
    case discipline(String)
    case life
}

extension TaskPlace {
    /// This place's kind and parent (spec §5): a project files Work under
    /// itself, a discipline files Study, and Life has no parent. The same
    /// derivation `CaptureContext.forSelection` seeds capture with.
    public var filing: TaskFiling {
        switch self {
        case .project(let id): TaskFiling(area: .work, parent: .project(id))
        case .discipline(let id): TaskFiling(area: .study, parent: .discipline(id))
        case .life: TaskFiling(area: .life, parent: nil)
        }
    }

    /// This place's cached open tasks (spec §5): `PlaceSync`'s prune step and
    /// `PlaceTasksView`'s `@Query` share this one definition, so a task never
    /// reads as open in one and missing from the other.
    ///
    ///     let predicate = TaskPlace.discipline("d1").openTasksPredicate
    public var openTasksPredicate: Predicate<TaskRecord> {
        switch self {
        case .project(let id):
            let target: String? = id
            return #Predicate<TaskRecord> { $0.projectID == target && !$0.isCompleted }
        case .discipline(let id):
            let target: String? = id
            return #Predicate<TaskRecord> { $0.disciplineID == target && !$0.isCompleted }
        case .life:
            let target = TaskArea.life.rawValue
            return #Predicate<TaskRecord> { $0.area == target && !$0.isCompleted }
        }
    }
}
