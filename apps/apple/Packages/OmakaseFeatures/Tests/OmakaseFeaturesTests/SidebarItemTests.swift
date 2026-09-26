import Testing

@testable import OmakaseFeatures

/// The sidebar lists only screens that exist. M1's Today list is Focus's
/// list view, so Focus is the one item until Plan, Review, Projects and Study
/// arrive with their screens (M2 plan, Task M4).
struct SidebarItemTests {
    @Test func onlyScreensThatExistAreListed() {
        #expect(SidebarItem.allCases == [.focus])
    }

    @Test func focusFollowsTheWebClientsNaming() {
        #expect(SidebarItem.focus.title == "Focus")
        #expect(SidebarItem.focus.symbol == "scope")
        #expect(SidebarItem.focus.id == .focus)
    }
}
