import OmakaseStore

/// What the sidebar has selected: one of its screens, or a place — a
/// project, a discipline, or Life (spec §3). `MainWindowView` persists it
/// with `@SceneStorage("omakase.sidebar")` by this raw value, so relaunching
/// returns to where the user was.
///
///     SidebarSelection.place(.project("42")).rawValue   // "place.project.42"
///     SidebarSelection(rawValue: "place.life")           // .place(.life)
public enum SidebarSelection: Hashable, RawRepresentable, Sendable {
    case item(SidebarItem)
    case place(TaskPlace)

    public init?(rawValue: String) {
        if let item = SidebarItem(rawValue: rawValue) {
            self = .item(item)
            return
        }
        guard let place = Self.place(fromRaw: rawValue) else { return nil }
        self = .place(place)
    }

    public var rawValue: String {
        switch self {
        case .item(let item): item.rawValue
        case .place(let place): place.rawValue
        }
    }

    /// `.item(.focus)` when `self` is a place missing from `knownPlaces`
    /// (deleted or archived since the selection was saved, or — until S6
    /// lists any places at all — always); otherwise `self` unchanged.
    public func valid(knownPlaces: Set<TaskPlace>) -> SidebarSelection {
        guard case .place(let place) = self, !knownPlaces.contains(place) else { return self }
        return .item(.focus)
    }

    /// Parses `"place.project.<id>"`, `"place.discipline.<id>"` or
    /// `"place.life"`; anything else, including a bare `"place"`, is nil.
    private static func place(fromRaw raw: String) -> TaskPlace? {
        let parts = raw.split(separator: ".", maxSplits: 2)
        guard parts.first == "place" else { return nil }
        if parts.count == 2, parts[1] == "life" { return .life }
        guard parts.count == 3 else { return nil }
        switch parts[1] {
        case "project": return .project(String(parts[2]))
        case "discipline": return .discipline(String(parts[2]))
        default: return nil
        }
    }
}

extension TaskPlace {
    fileprivate var rawValue: String {
        switch self {
        case .project(let id): "place.project.\(id)"
        case .discipline(let id): "place.discipline.\(id)"
        case .life: "place.life"
        }
    }
}
