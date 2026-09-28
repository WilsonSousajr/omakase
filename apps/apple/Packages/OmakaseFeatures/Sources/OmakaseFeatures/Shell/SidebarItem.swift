/// A screen in the window's sidebar. A case exists only once its screen does.
/// The sidebar lists the day (`day`) as rows; Projects and Study open from
/// the Work and Study headers above their places (spec §6, #260).
///
///     ForEach(SidebarItem.day) { item in SidebarRowView(item: item, count: 0).tag(SidebarSelection.item(item)) }
public enum SidebarItem: String, CaseIterable, Identifiable, Sendable {
    /// The day or week as a calendar, with the task column to plan from (M4).
    case plan
    /// Today's tasks. M1's list is Focus's list view; M3 adds the board and timer.
    case focus
    /// The day's close: summary, rating, energy and win (M3.4).
    case review
    /// Tasks with no date, to triage (M5, #225).
    case inbox
    /// Workspaces and their projects (M5, #226).
    case projects
    /// Semesters, disciplines, class schedules and holidays (M5, #227).
    case study

    /// The day's screens, in the sidebar's order: Focus leads because the
    /// app opens on it (spec §6). Plan led until M9, as the web client's
    /// navigation did; the user changed that in the M9 brainstorm.
    public static let day: [SidebarItem] = [.focus, .plan, .review, .inbox]

    public var id: Self { self }

    public var title: String {
        switch self {
        case .plan: "Plan"
        case .focus: "Focus"
        case .review: "Review"
        case .inbox: "Inbox"
        case .projects: "Projects"
        case .study: "Study"
        }
    }

    public var symbol: String {
        switch self {
        case .plan: "calendar"
        case .focus: "scope"
        case .review: "moon.stars"
        case .inbox: "tray"
        case .projects: "folder"
        case .study: "graduationcap"
        }
    }
}
