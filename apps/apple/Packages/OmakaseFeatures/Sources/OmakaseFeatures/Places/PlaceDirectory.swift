import Foundation
import OmakaseStore
import SwiftData

/// A kind's own colour and title: the mark a task shows when its parent is
/// unknown or absent (spec §2, `PlaceDirectory.mark(for:)`).
public struct KindMark: Equatable, Sendable {
    public let title: String
    public let color: DesignColor

    public init(title: String, color: DesignColor) {
        self.title = title
        self.color = color
    }
}

/// One place a task can be filed under: a project or a discipline, with the
/// colour it shows (spec §2).
public struct PlaceEntry: Equatable, Sendable, Identifiable {
    public let parent: TaskParent
    public let title: String
    /// The workspace's name, only when there is more than one workspace; nil for a discipline.
    public let group: String?
    public let color: DesignColor

    public var id: TaskParent { parent }

    public init(parent: TaskParent, title: String, group: String?, color: DesignColor) {
        self.parent = parent
        self.title = title
        self.group = group
        self.color = color
    }
}

/// A project's fields the selection below needs, decoupled from SwiftData
/// so it is plain-value testable (spec §2).
struct ProjectSpan: Equatable {
    let id: String
    let workspaceID: String
    let name: String
    let color: String
    let status: String
}

/// A semester's fields the current-semester choice needs (spec §2).
struct SemesterSpan: Equatable {
    let id: String
    let name: String
    let startDay: String
    let endDay: String
    let status: String
}

/// A discipline's fields the selection below needs (spec §2).
struct DisciplineSpan: Equatable {
    let id: String
    let semesterID: String
    let name: String
    let color: String
    let status: String
}

extension ProjectSpan {
    @MainActor init(_ record: ProjectRecord) {
        self.init(
            id: record.id, workspaceID: record.workspaceID, name: record.name, color: record.color,
            status: record.status)
    }
}

extension SemesterSpan {
    @MainActor init(_ record: SemesterRecord) {
        self.init(
            id: record.id, name: record.name, startDay: record.startDay, endDay: record.endDay, status: record.status)
    }
}

extension DisciplineSpan {
    @MainActor init(_ record: DisciplineRecord) {
        self.init(
            id: record.id, semesterID: record.semesterID, name: record.name, color: record.color,
            status: record.status)
    }
}

/// Answers "what is this task's place called, and what colour does it
/// show?" (spec §2): active projects grouped by workspace, and the current
/// semester's active disciplines, from the library cache.
///
///     let mark = directory.mark(for: task.filing)
///     Text(mark.title).foregroundStyle(mark.color.color)
public struct PlaceDirectory: Equatable, Sendable {
    public static let empty = PlaceDirectory(projects: [], disciplines: [], semesterTitle: nil)

    public let projects: [PlaceEntry]
    public let disciplines: [PlaceEntry]
    public let semesterTitle: String?

    public init(projects: [PlaceEntry], disciplines: [PlaceEntry], semesterTitle: String?) {
        self.projects = projects
        self.disciplines = disciplines
        self.semesterTitle = semesterTitle
    }

    /// Reads the library cache (spec §2): active projects, grouped by
    /// workspace when there is more than one, and the current semester's
    /// active disciplines.
    @MainActor
    public static func load(from context: ModelContext, today: String) -> PlaceDirectory {
        let workspaces = (try? context.fetch(FetchDescriptor<WorkspaceRecord>())) ?? []
        let names = Dictionary(uniqueKeysWithValues: workspaces.map { ($0.id, $0.name) })
        let projectSpans = ((try? context.fetch(FetchDescriptor<ProjectRecord>())) ?? []).map(ProjectSpan.init)
        let semesterSpans = ((try? context.fetch(FetchDescriptor<SemesterRecord>())) ?? []).map(SemesterSpan.init)
        let disciplineSpans = ((try? context.fetch(FetchDescriptor<DisciplineRecord>())) ?? []).map(DisciplineSpan.init)
        let semester = currentSemester(semesterSpans, today: today)
        return PlaceDirectory(
            projects: projectEntries(projectSpans, workspaceNames: names),
            disciplines: semester.map { disciplineEntries(disciplineSpans, semesterID: $0.id) } ?? [],
            semesterTitle: semester?.name)
    }

    /// A kind's places: work → its projects, study → its disciplines, life → none.
    public func places(for area: TaskArea) -> [PlaceEntry] {
        switch area {
        case .work: projects
        case .study: disciplines
        case .life: []
        }
    }

    /// A filing's title and colour (spec §2): the parent's entry when it is
    /// still known, else the kind's own title and token.
    public func mark(for filing: TaskFiling) -> KindMark {
        guard let parent = filing.parent, let entry = entry(for: parent) else {
            return KindMark(title: filing.area.title, color: KindTint.token(for: filing.area))
        }
        return KindMark(title: entry.title, color: entry.color)
    }

    /// Every place a filing can resolve to today, plus Life, which has no entries of its own.
    public var knownPlaces: Set<TaskPlace> {
        var places = Set((projects + disciplines).map(\.parent).map(Self.place(for:)))
        places.insert(.life)
        return places
    }

    private static func place(for parent: TaskParent) -> TaskPlace {
        switch parent {
        case .project(let id): .project(id)
        case .discipline(let id): .discipline(id)
        }
    }

    private func entry(for parent: TaskParent) -> PlaceEntry? {
        switch parent {
        case .project: projects.first { $0.parent == parent }
        case .discipline: disciplines.first { $0.parent == parent }
        }
    }

    /// The active semester containing `today`, else the latest-starting active one, else none.
    static func currentSemester(_ semesters: [SemesterSpan], today: String) -> SemesterSpan? {
        let active = semesters.filter { $0.status == "active" }
        if let containing = active.first(where: { $0.startDay <= today && today <= $0.endDay }) {
            return containing
        }
        return active.max { $0.startDay < $1.startDay }
    }

    /// Active projects, sorted by workspace name then project name; grouped
    /// under the workspace's name only when there is more than one workspace.
    static func projectEntries(_ projects: [ProjectSpan], workspaceNames: [String: String]) -> [PlaceEntry] {
        let groupByWorkspace = workspaceNames.count > 1
        return
            projects
            .filter { $0.status == "active" }
            .sorted { sortsBeforeByWorkspace($0, $1, workspaceNames: workspaceNames) }
            .map { project in
                PlaceEntry(
                    parent: .project(project.id), title: project.name,
                    group: groupByWorkspace ? workspaceNames[project.workspaceID] : nil,
                    color: KindTint.mark(for: .work, parentHex: project.color))
            }
    }

    private static func sortsBeforeByWorkspace(
        _ lhs: ProjectSpan, _ rhs: ProjectSpan, workspaceNames: [String: String]
    ) -> Bool {
        let (lhsGroup, rhsGroup) = (workspaceNames[lhs.workspaceID] ?? "", workspaceNames[rhs.workspaceID] ?? "")
        return lhsGroup == rhsGroup ? lhs.name < rhs.name : lhsGroup < rhsGroup
    }

    /// A semester's active disciplines, sorted by name.
    static func disciplineEntries(_ disciplines: [DisciplineSpan], semesterID: String) -> [PlaceEntry] {
        disciplines
            .filter { $0.semesterID == semesterID && $0.status == "active" }
            .sorted { $0.name < $1.name }
            .map { discipline in
                PlaceEntry(
                    parent: .discipline(discipline.id), title: discipline.name, group: nil,
                    color: KindTint.mark(for: .study, parentHex: discipline.color))
            }
    }
}
