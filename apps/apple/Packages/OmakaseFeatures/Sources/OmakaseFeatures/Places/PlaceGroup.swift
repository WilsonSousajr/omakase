/// A run of places under one heading in a parent menu (spec §4): a
/// workspace's projects, or places with no group at all. Capture's parent
/// chip builds its sections from these, and so can the editor's (S5).
///
///     ForEach(PlaceGroup.groups(of: directory.places(for: .work))) { group in Section(group.title ?? "") { … } }
public struct PlaceGroup: Equatable, Sendable, Identifiable {
    /// The workspace's name, or nil for places with no group.
    public let title: String?
    public let entries: [PlaceEntry]

    public var id: String { title ?? "" }

    public init(title: String?, entries: [PlaceEntry]) {
        self.title = title
        self.entries = entries
    }

    /// `entries` split into runs of the same `group`, keeping their order;
    /// `PlaceDirectory` already sorts projects by workspace, so each
    /// workspace is one run.
    public static func groups(of entries: [PlaceEntry]) -> [PlaceGroup] {
        entries.reduce(into: []) { groups, entry in
            guard let last = groups.last, last.title == entry.group else {
                return groups.append(PlaceGroup(title: entry.group, entries: [entry]))
            }
            groups[groups.count - 1] = PlaceGroup(title: last.title, entries: last.entries + [entry])
        }
    }
}
