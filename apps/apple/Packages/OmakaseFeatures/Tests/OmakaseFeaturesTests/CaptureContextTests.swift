import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// What the capture panel opens with, from where it was opened (spec §4's
/// table, #257).
struct CaptureContextTests {
    @Test func aCommandWithNoFocusedWindowOpensWithTheDefault() {
        #expect(CaptureContext.forCommand(focused: nil) == CaptureContext())
    }

    @Test func aCommandKeepsTheFocusedWindowsContext() {
        let focused = CaptureContext(day: "2026-09-28")
        #expect(CaptureContext.forCommand(focused: focused) == focused)
    }

    @Test func theDefaultHasNoFilingDayOrSlot() {
        let context = CaptureContext()
        #expect(context.filing == nil)
        #expect(context.day == nil)
        #expect(context.slot == nil)
    }

    @Test func planSeedsTheDayItShows() {
        let context = CaptureContext.forSelection(.item(.plan), planDay: "2026-09-28")
        #expect(context == CaptureContext(day: "2026-09-28"))
    }

    @Test func planWithoutItsModelSeedsNoDay() {
        #expect(CaptureContext.forSelection(.item(.plan), planDay: nil) == CaptureContext())
    }

    @Test(arguments: [SidebarItem.focus, .review, .inbox, .projects, .study])
    func otherScreensSeedTheDefault(item: SidebarItem) {
        #expect(CaptureContext.forSelection(.item(item), planDay: "2026-09-28") == CaptureContext())
    }

    @Test func aProjectsListSeedsWorkUnderThatProject() {
        let context = CaptureContext.forSelection(.place(.project("p1")), planDay: "2026-09-28")
        #expect(context == CaptureContext(filing: TaskFiling(area: .work, parent: .project("p1"))))
    }

    @Test func aDisciplinesListSeedsStudyUnderThatDiscipline() {
        let context = CaptureContext.forSelection(.place(.discipline("d1")), planDay: nil)
        #expect(context == CaptureContext(filing: TaskFiling(area: .study, parent: .discipline("d1"))))
    }

    @Test func lifeSeedsLifeWithNoParent() {
        let context = CaptureContext.forSelection(.place(.life), planDay: nil)
        #expect(context == CaptureContext(filing: TaskFiling(area: .life, parent: nil)))
    }
}
