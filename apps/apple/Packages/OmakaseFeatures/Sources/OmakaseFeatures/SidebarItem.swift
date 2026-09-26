/// A screen in the window's sidebar, in the web client's navigation (Plan,
/// Focus, Review, Projects, Study). A case exists only once its screen does.
///
///     List(SidebarItem.allCases, selection: $selection) { Label($0.title, systemImage: $0.symbol) }
public enum SidebarItem: String, CaseIterable, Identifiable, Sendable {
    /// Today's tasks. M1's list is Focus's list view; M3 adds the board and timer.
    case focus

    public var id: Self { self }

    public var title: String {
        switch self {
        case .focus: "Focus"
        }
    }

    public var symbol: String {
        switch self {
        case .focus: "scope"
        }
    }
}
