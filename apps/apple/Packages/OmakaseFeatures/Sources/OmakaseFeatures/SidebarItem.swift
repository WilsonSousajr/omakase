/// A screen in the window's sidebar, in the web client's navigation (Plan,
/// Focus, Review, Projects, Study). A case exists only once its screen does.
///
///     List(SidebarItem.allCases, selection: $selection) { Label($0.title, systemImage: $0.symbol) }
public enum SidebarItem: String, CaseIterable, Identifiable, Sendable {
    /// The day or week as a calendar, with the task column to plan from (M4).
    case plan
    /// Today's tasks. M1's list is Focus's list view; M3 adds the board and timer.
    case focus
    /// The day's close: summary, rating, energy and win (M3.4).
    case review
    /// Tasks with no date, to triage (M5, #225).
    case inbox

    public var id: Self { self }

    public var title: String {
        switch self {
        case .plan: "Plan"
        case .focus: "Focus"
        case .review: "Review"
        case .inbox: "Inbox"
        }
    }

    public var symbol: String {
        switch self {
        case .plan: "calendar"
        case .focus: "scope"
        case .review: "moon.stars"
        case .inbox: "tray"
        }
    }
}
