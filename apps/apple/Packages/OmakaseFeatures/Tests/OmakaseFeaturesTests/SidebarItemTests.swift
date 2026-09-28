import Testing

@testable import OmakaseFeatures

/// The sidebar lists only screens that exist. M1's Today list is Focus's
/// list view; Review arrives with its screen in M3.4 (#178), Plan with its
/// calendar in M4 (#202), the Inbox in M5 (#225), and Projects and Study
/// follow with theirs.
struct SidebarItemTests {
    @Test func onlyScreensThatExistAreListed() {
        #expect(SidebarItem.allCases == [.plan, .focus, .review, .inbox, .projects, .study])
    }

    @Test func focusFollowsTheWebClientsNaming() {
        #expect(SidebarItem.focus.title == "Focus")
        #expect(SidebarItem.focus.symbol == "scope")
        #expect(SidebarItem.focus.id == .focus)
    }

    @Test func reviewFollowsTheWebClientsNaming() {
        #expect(SidebarItem.review.title == "Review")
        #expect(SidebarItem.review.symbol == "moon.stars")
    }

    /// Focus leads the day because the app opens on it (M9 spec §6, decided
    /// with the user in the M9 brainstorm, #260). Plan led until then, as
    /// the web client's navigation did; Projects and Study left the day for
    /// the Work and Study headers.
    @Test func focusLeadsTheDay() {
        #expect(SidebarItem.day == [.focus, .plan, .review, .inbox])
    }

    @Test func planIsTheCalendar() {
        #expect(SidebarItem.plan.title == "Plan")
        #expect(SidebarItem.plan.symbol == "calendar")
    }

    @Test func theInboxHoldsWhatHasNoDay() {
        #expect(SidebarItem.inbox.title == "Inbox")
        #expect(SidebarItem.inbox.symbol == "tray")
    }

    @Test func projectsFollowTheWebClientsNaming() {
        #expect(SidebarItem.projects.title == "Projects")
        #expect(SidebarItem.projects.symbol == "folder")
    }

    @Test func studyFollowsTheWebClientsNaming() {
        #expect(SidebarItem.study.title == "Study")
        #expect(SidebarItem.study.symbol == "graduationcap")
    }
}
