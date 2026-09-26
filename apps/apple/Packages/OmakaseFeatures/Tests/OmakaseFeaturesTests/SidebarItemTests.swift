import Testing

@testable import OmakaseFeatures

/// The sidebar lists only screens that exist. M1's Today list is Focus's
/// list view; Review arrives with its screen in M3.4 (#178), and Plan,
/// Projects and Study follow with theirs.
struct SidebarItemTests {
    @Test func onlyScreensThatExistAreListed() {
        #expect(SidebarItem.allCases == [.focus, .review])
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
}
