/// A place a task can be filed: a project, a discipline, or Life. `S6` adds
/// the predicate that lists a place's tasks and keeps this set in sync with
/// the library cache; this slice only names the three cases (spec §3, §5).
public enum TaskPlace: Hashable, Sendable {
    case project(String)
    case discipline(String)
    case life
}
