import Foundation
import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// What ⌘E opens in the capture panel (glass-pass §4, #286): the day,
/// priority, estimate, notes and subtasks, and what a save sends of them.
@MainActor
struct CaptureDetailsTests {
    static let utc = CaptureModelTests.utc
    static let directory = CaptureModelTests.directory
    /// Monday 28 September 2026, 14:00-15:00.
    static let slot = CaptureModelTests.slot
    /// Sunday 27 September 2026, the client's day (invariant 2).
    static let today = "2026-09-27"

    private func model(
        _ context: CaptureContext = CaptureContext(), directory: PlaceDirectory = directory,
        isExpanded: Bool = false, recorder: CaptureRecorder = CaptureRecorder()
    ) -> CaptureModel {
        CaptureModel(
            context: context, directory: directory, lastArea: .work, isExpanded: isExpanded, calendar: Self.utc,
            today: { Self.today }, actions: recorder.actions)
    }

    // MARK: ⌘E, and remembering it

    @Test func commandEExpandsThenCollapsesAndRemembersEach() {
        let recorder = CaptureRecorder()
        let model = model(recorder: recorder)
        #expect(!model.isExpanded)
        model.toggleExpanded()
        #expect(model.isExpanded)
        model.toggleExpanded()
        #expect(!model.isExpanded)
        #expect(recorder.events == [.rememberExpanded(true), .rememberExpanded(false)])
    }

    @Test func collapsingLeavesTheSubtaskLines() {
        let model = model(isExpanded: true)
        model.isEditingSubtasks = true
        model.toggleExpanded()
        #expect(!model.isEditingSubtasks)
        #expect(model.hint == "⌘E more/less · ⏎ Today · ⌘⏎ Inbox · ⎋")
    }

    @Test func thePanelOpensExpandedWhenThatWasRemembered() {
        #expect(model(isExpanded: true).isExpanded)
    }

    /// `UserDefaults.object(forKey:)` hands back an `NSNumber` for a stored Bool.
    @Test func theRememberedExpansionReadsBackOrIsCollapsed() {
        #expect(CaptureExpansion.isExpanded(stored: true))
        #expect(CaptureExpansion.isExpanded(stored: NSNumber(value: true)))
        #expect(!CaptureExpansion.isExpanded(stored: false))
        #expect(!CaptureExpansion.isExpanded(stored: nil))
        #expect(!CaptureExpansion.isExpanded(stored: "true"))
    }

    // MARK: The date replaces where ⏎ saves

    @Test func aPickedDayReplacesTheContextsDay() {
        let model = model(CaptureContext(day: "2026-09-28"))
        model.details.date = "2026-09-30"
        #expect(model.enterDestination == .day("2026-09-30"))
        #expect(model.hint == "⌘E more/less · ⏎ Wed 30 · ⌘⏎ Inbox · ⎋")
    }

    @Test func pickingTheSlotsDayKeepsTheSlot() {
        let model = model(CaptureContext(slot: Self.slot))
        model.details.date = "2026-09-28"
        #expect(model.enterDestination == .slot(Self.slot))
    }

    @Test func pickingAnotherDayDropsTheSlotForThatDay() {
        let model = model(CaptureContext(slot: Self.slot))
        model.details.date = "2026-09-29"
        #expect(model.enterDestination == .day("2026-09-29"))
    }

    @Test func pickingTodayIsToday() {
        let model = model(CaptureContext(day: "2026-09-28"))
        model.details.date = Self.today
        #expect(model.enterDestination == .today)
    }

    @Test(
        arguments: [
            (CaptureContext(), "2026-09-27"), (CaptureContext(day: "2026-09-28"), "2026-09-28"),
            (
                CaptureContext(day: "2026-09-30", slot: PlanPlacement(day: "2026-09-28", start: 840, end: 900)),
                "2026-09-28"
            ),
        ])
    func theDateFieldShowsWhereEnterSaves(context: CaptureContext, day: String) {
        let model = model(context)
        #expect(model.pickedDate == DayString.date(day, calendar: Self.utc))
    }

    @Test func settingTheDateFieldPicksItsDay() throws {
        let model = model()
        model.pickedDate = try #require(DayString.date("2026-10-02", calendar: Self.utc))
        #expect(model.details.date == "2026-10-02")
        #expect(model.enterDestination == .day("2026-10-02"))
    }

    // MARK: Priority and estimate

    @Test func priorityShowsMediumUntilChosen() {
        let model = model()
        #expect(model.shownPriority == "medium")
        model.choose(priority: "high")
        #expect(model.shownPriority == "high" && model.details.priority == "high")
    }

    @Test func theEstimateIsNamedAsTheAppWritesIt() {
        let model = model()
        #expect(model.estimateTitle == "Estimate")
        model.choose(estimate: 90)
        #expect(model.estimateTitle == "1h 30m")
        model.choose(estimate: nil)
        #expect(model.details.estimateMinutes == nil)
        #expect(CaptureModel.estimateChoices == [15, 30, 45, 60, 90, 120, 180, 240])
    }

    // MARK: Subtasks, one per line

    @Test func returnOnAFilledLineAddsOneAfterIt() {
        let model = model()
        model.setSubtask("Outline", at: 0)
        #expect(model.addSubtaskLine(after: 0) == 1)
        model.setSubtask("Send", at: 1)
        #expect(model.addSubtaskLine(after: 0) == 1)
        #expect(model.details.subtasks == ["Outline", "", "Send"])
    }

    @Test(arguments: [0, 3, -1])
    func returnOnABlankOrMissingLineAddsNothing(index: Int) {
        let model = model()
        #expect(model.addSubtaskLine(after: index) == nil)
        #expect(model.details.subtasks == [""])
    }

    @Test func aLineOutOfRangeReadsEmptyAndIgnoresWrites() {
        let model = model()
        model.setSubtask("Ghost", at: 4)
        #expect(model.subtask(at: 4).isEmpty && model.subtask(at: -1).isEmpty)
        #expect(model.details.subtasks == [""])
    }

    // MARK: ⌘⏎ and the hint while typing subtasks

    @Test func commandReturnInTheSubtasksSavesWhereEnterWould() {
        let recorder = CaptureRecorder()
        let model = model(CaptureContext(day: "2026-09-28"), recorder: recorder)
        model.draft = "Email the advisor"
        model.isEditingSubtasks = true
        #expect(model.hint == "⌘E more/less · ⏎ new subtask · ⌘⏎ Mon 28 · ⎋")
        #expect(model.saveCommandReturn())
        #expect(recorder.requests.map(\.destination) == [.day("2026-09-28")])
    }

    @Test func commandReturnElsewhereSavesToTheInbox() {
        let recorder = CaptureRecorder()
        let model = model(CaptureContext(day: "2026-09-28"), recorder: recorder)
        model.draft = "Email the advisor"
        #expect(model.saveCommandReturn())
        #expect(recorder.requests.map(\.destination) == [.inbox])
    }

    // MARK: What a save sends

    @Test func aSaveSendsTheDetailsTrimmedWithBlankLinesDropped() {
        let recorder = CaptureRecorder()
        let model = model(recorder: recorder)
        model.draft = "Email the advisor"
        model.choose(priority: "high")
        model.choose(estimate: 45)
        model.details.notes = "  Ask about §3\n"
        model.details.subtasks = ["Outline", "  ", " Draft ", ""]
        #expect(model.saveEnter())
        let sent = TaskCaptureDetails(
            priority: "high", estimatedMinutes: 45, notes: "Ask about §3", subtasks: ["Outline", "Draft"])
        #expect(recorder.requests.map(\.details) == [sent])
    }

    @Test func untouchedDetailsSendNothing() {
        let recorder = CaptureRecorder()
        let model = model(isExpanded: true, recorder: recorder)
        model.draft = "Email the advisor"
        model.details.notes = " \n"
        #expect(model.saveEnter())
        #expect(recorder.requests.map(\.details) == [TaskCaptureDetails()])
    }

    @Test func aSaveClearsTheDetailsAndStaysExpanded() {
        let model = model(isExpanded: true)
        model.draft = "Email the advisor"
        model.details = CaptureDetails(date: "2026-09-30", priority: "low", notes: "x", subtasks: ["a", ""])
        model.isEditingSubtasks = true
        model.saveEnter()
        #expect(model.details == CaptureDetails())
        #expect(model.isExpanded && !model.isEditingSubtasks)
    }

    @Test func dismissClearsTheDetails() {
        let model = model()
        model.details.subtasks = ["Outline"]
        model.dismiss()
        #expect(model.details == CaptureDetails())
    }

    // MARK: The block a drawn slot books

    @Test func onlyASlotBooksABlock() {
        let booked = CaptureSlot(day: "2026-09-28", start: "14:00:00", end: "15:00:00")
        #expect(CaptureDestination.slot(Self.slot).captureSlot == booked)
        #expect(CaptureDestination.day("2026-09-28").captureSlot == nil)
        #expect(CaptureDestination.today.captureSlot == nil && CaptureDestination.inbox.captureSlot == nil)
    }
}
