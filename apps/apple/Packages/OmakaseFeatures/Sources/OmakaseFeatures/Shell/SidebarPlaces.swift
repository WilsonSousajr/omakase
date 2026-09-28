import OmakaseStore

/// A place's row under its kind's header: its title, its colour as a mark,
/// and how many open tasks its list holds.
public struct SidebarPlaceRow: Equatable, Sendable, Identifiable {
    public let place: TaskPlace
    public let title: String
    public let color: DesignColor
    public let count: Int

    public var id: TaskPlace { place }

    public init(place: TaskPlace, title: String, color: DesignColor, count: Int) {
        (self.place, self.title, self.color, self.count) = (place, title, color, count)
    }
}

/// A run of place rows under an optional sub-header: a workspace's name
/// (only when there is more than one), or the semester's title.
public struct SidebarPlaceGroup: Equatable, Sendable, Identifiable {
    public let title: String?
    public let rows: [SidebarPlaceRow]

    public var id: String { title ?? "" }

    public init(title: String?, rows: [SidebarPlaceRow]) { (self.title, self.rows) = (title, rows) }
}

/// A kind's part of the sidebar: a selectable header that opens the kind's
/// screen (Work → Projects, Study → Study, Life → its own list), counting
/// what its places hold, then its places.
public struct SidebarKindSection: Equatable, Sendable, Identifiable {
    public let area: TaskArea
    /// What selecting the header shows.
    public let selection: SidebarSelection
    /// The sum of its places' counts; Life's own count.
    public let count: Int
    public let groups: [SidebarPlaceGroup]

    public var id: TaskArea { area }

    public init(area: TaskArea, selection: SidebarSelection, count: Int, groups: [SidebarPlaceGroup]) {
        (self.area, self.selection, self.count, self.groups) = (area, selection, count, groups)
    }
}

/// The sidebar's places, grouped (spec §6, #260): Work's active projects
/// (under workspace sub-headers when there is more than one workspace),
/// Study's current semester's active disciplines under its title, and
/// Life, which is always there.
///
///     ForEach(SidebarPlaces.sections(directory, counts: counts)) { section in … }
public enum SidebarPlaces {
    /// Work, Study and Life, in that order, each with its places and counts.
    public static func sections(_ directory: PlaceDirectory, counts: SidebarCounts) -> [SidebarKindSection] {
        [
            section(.work, opens: .item(.projects), groups: PlaceGroup.groups(of: directory.projects), counts: counts),
            section(.study, opens: .item(.study), groups: studyGroups(directory), counts: counts),
            SidebarKindSection(area: .life, selection: .place(.life), count: counts.count(for: .life), groups: []),
        ]
    }

    /// The semester's disciplines under its title; none when there is no
    /// current semester or it has no active disciplines.
    private static func studyGroups(_ directory: PlaceDirectory) -> [PlaceGroup] {
        guard !directory.disciplines.isEmpty else { return [] }
        return [PlaceGroup(title: directory.semesterTitle, entries: directory.disciplines)]
    }

    private static func section(
        _ area: TaskArea, opens selection: SidebarSelection, groups: [PlaceGroup], counts: SidebarCounts
    ) -> SidebarKindSection {
        let placeGroups = groups.map { group in
            SidebarPlaceGroup(title: group.title, rows: group.entries.map { row($0, counts: counts) })
        }
        let total = placeGroups.flatMap(\.rows).reduce(0) { $0 + $1.count }
        return SidebarKindSection(area: area, selection: selection, count: total, groups: placeGroups)
    }

    private static func row(_ entry: PlaceEntry, counts: SidebarCounts) -> SidebarPlaceRow {
        let place = PlaceDirectory.place(for: entry.parent)
        return SidebarPlaceRow(place: place, title: entry.title, color: entry.color, count: counts.count(for: place))
    }
}
