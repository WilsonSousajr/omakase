import Foundation
import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// Records what the model asks the app for, in order: each capture and
/// each remembered kind.
@MainActor
final class CaptureRecorder {
    enum Event: Equatable {
        case capture(CaptureRequest)
        case remember(TaskArea)
    }

    private(set) var events: [Event] = []

    var requests: [CaptureRequest] {
        events.compactMap { event in
            guard case .capture(let request) = event else { return nil }
            return request
        }
    }

    var actions: CaptureModel.Actions {
        CaptureModel.Actions(
            capture: { [self] in events.append(.capture($0)) }, remember: { [self] in events.append(.remember($0)) })
    }
}

/// The capture panel's draft, kind and parent (spec §4, #257).
@MainActor
struct CaptureModelTests {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    static let thesis = PlaceEntry(parent: .project("p1"), title: "Thesis", group: nil, color: KindTint.work)
    static let algebra = PlaceEntry(
        parent: .discipline("d1"), title: "Linear algebra", group: nil, color: KindTint.study)
    static let directory = PlaceDirectory(projects: [thesis], disciplines: [algebra], semesterTitle: "Fall")
    /// Monday 28 September 2026, 14:00-15:00.
    static let slot = PlanPlacement(day: "2026-09-28", start: 840, end: 900)

    private func model(
        _ context: CaptureContext = CaptureContext(), directory: PlaceDirectory = directory,
        lastArea: TaskArea = .work, recorder: CaptureRecorder = CaptureRecorder()
    ) -> CaptureModel {
        CaptureModel(
            context: context, directory: directory, lastArea: lastArea, calendar: Self.utc, actions: recorder.actions)
    }

    // MARK: The initial kind and parent

    @Test func aContextsFilingSeedsTheKindAndParent() {
        let context = CaptureContext(filing: TaskFiling(area: .study, parent: .discipline("d1")))
        let model = model(context, lastArea: .life)
        #expect(model.area == .study)
        #expect(model.parent == .discipline("d1"))
    }

    @Test func withNoFilingTheLastKindIsUsed() {
        let model = model(lastArea: .life)
        #expect(model.area == .life)
        #expect(model.parent == nil)
    }

    // MARK: Choosing a kind or a parent

    @Test func choosingAKindClearsAParentThatNoLongerFits() {
        let model = model(CaptureContext(filing: TaskFiling(area: .study, parent: .discipline("d1"))))
        model.choose(.work)
        #expect(model.area == .work)
        #expect(model.parent == nil)
    }

    @Test(arguments: [TaskArea.study, .life])
    func choosingAnotherKindClearsAProject(area: TaskArea) {
        let model = model(CaptureContext(filing: TaskFiling(area: .work, parent: .project("p1"))))
        model.choose(area)
        #expect(model.area == area)
        #expect(model.parent == nil)
    }

    @Test func choosingTheSameKindKeepsAParentThatFits() {
        let model = model(CaptureContext(filing: TaskFiling(area: .work, parent: .project("p1"))))
        model.choose(.work)
        #expect(model.parent == .project("p1"))
    }

    @Test func choosingADisciplineMakesTheTaskStudy() {
        let model = model(lastArea: .work)
        model.choose(parent: .discipline("d1"))
        #expect(model.area == .study)
        #expect(model.filing == TaskFiling(area: .study, parent: .discipline("d1")))
    }

    @Test func choosingAProjectMakesTheTaskWork() {
        let model = model(lastArea: .life)
        model.choose(parent: .project("p1"))
        #expect(model.area == .work)
        #expect(model.parent == .project("p1"))
    }

    @Test func choosingNoParentKeepsTheKind() {
        let model = model(CaptureContext(filing: TaskFiling(area: .study, parent: .discipline("d1"))))
        model.choose(parent: nil)
        #expect(model.filing == TaskFiling(area: .study, parent: nil))
    }

    // MARK: The parent chip

    @Test func workListsProjectsAndStudyListsDisciplines() {
        let model = model(lastArea: .work)
        #expect(model.parentChoices == [Self.thesis])
        model.choose(.study)
        #expect(model.parentChoices == [Self.algebra])
        #expect(model.showsParentChip)
    }

    @Test func lifeHidesTheParentChip() {
        let model = model(lastArea: .life)
        #expect(model.parentChoices.isEmpty)
        #expect(!model.showsParentChip)
    }

    @Test func anEmptyDirectoryHidesTheChipAndSavesTheKindAlone() {
        let recorder = CaptureRecorder()
        let model = model(directory: .empty, lastArea: .study, recorder: recorder)
        #expect(!model.showsParentChip)
        model.draft = "Read chapter 4"
        #expect(model.saveEnter())
        #expect(recorder.requests.map(\.filing) == [TaskFiling(area: .study, parent: nil)])
    }

    @Test func theChipNamesTheParentOrItsAbsence() {
        let model = model(lastArea: .work)
        #expect(model.parentTitle == "No project")
        model.choose(.study)
        #expect(model.parentTitle == "No discipline")
        model.choose(parent: .discipline("d1"))
        #expect(model.parentTitle == "Linear algebra")
    }

    @Test func theChipGroupsProjectsByWorkspace() {
        let home = PlaceEntry(parent: .project("p2"), title: "Garden", group: "Home", color: KindTint.work)
        let grouped = PlaceDirectory(projects: [home], disciplines: [], semesterTitle: nil)
        #expect(model(directory: grouped).parentGroups == [PlaceGroup(title: "Home", entries: [home])])
    }

    // MARK: Saving

    @Test func saveCapturesTheTrimmedTitleThenRemembersTheKind() {
        let recorder = CaptureRecorder()
        let context = CaptureContext(filing: TaskFiling(area: .study, parent: .discipline("d1")))
        let model = model(context, recorder: recorder)
        model.draft = "  Read chapter 4 of Axler \n"
        #expect(model.save(to: .today))
        let request = CaptureRequest(
            title: "Read chapter 4 of Axler", filing: TaskFiling(area: .study, parent: .discipline("d1")),
            destination: .today)
        #expect(recorder.events == [.capture(request), .remember(.study)])
    }

    @Test(arguments: ["", "   ", "\n\t "])
    func anEmptyTitleSavesNothing(draft: String) {
        let recorder = CaptureRecorder()
        let model = model(recorder: recorder)
        model.draft = draft
        #expect(!model.save(to: .today))
        #expect(recorder.events.isEmpty)
    }

    @Test func theDraftClearsAfterASave() {
        let model = model()
        model.draft = "Buy stamps"
        model.save(to: .today)
        #expect(model.draft.isEmpty)
    }

    @Test func dismissClearsTheDraftWithoutSaving() {
        let recorder = CaptureRecorder()
        let model = model(recorder: recorder)
        model.draft = "Half a thought"
        model.dismiss()
        #expect(model.draft.isEmpty)
        #expect(recorder.events.isEmpty)
    }

    @Test func saveInboxAlwaysFilesToTheInbox() {
        let recorder = CaptureRecorder()
        let model = model(CaptureContext(day: "2026-09-28", slot: Self.slot), recorder: recorder)
        model.draft = "Buy stamps"
        #expect(model.saveInbox())
        #expect(recorder.requests.map(\.destination) == [.inbox])
    }

    @Test func saveEnterSavesToTheContextsDestination() {
        let recorder = CaptureRecorder()
        let model = model(CaptureContext(day: "2026-09-28"), recorder: recorder)
        model.draft = "Buy stamps"
        #expect(model.saveEnter())
        #expect(recorder.requests.map(\.destination) == [.day("2026-09-28")])
    }

    // MARK: Where ⏎ saves, and the hint that says so

    @Test func enterSavesForTodayByDefault() {
        let model = model()
        #expect(model.enterDestination == .today)
        #expect(model.hint == "⌘1–3 kind · ⏎ Today · ⌘⏎ Inbox · ⎋ dismiss")
    }

    @Test func enterSavesToThePlanDay() {
        let model = model(CaptureContext(day: "2026-09-28"))
        #expect(model.enterDestination == .day("2026-09-28"))
        #expect(model.hint == "⌘1–3 kind · ⏎ Mon 28 · ⌘⏎ Inbox · ⎋ dismiss")
    }

    @Test func aSlotWinsOverTheDay() {
        let model = model(CaptureContext(day: "2026-09-30", slot: Self.slot))
        #expect(model.enterDestination == .slot(Self.slot))
        #expect(model.hint == "⌘1–3 kind · ⏎ Mon 28, 14:00 · ⌘⏎ Inbox · ⎋ dismiss")
    }

    @Test func eachDestinationHasATitle() {
        #expect(CaptureDestination.today.title(calendar: Self.utc) == "Today")
        #expect(CaptureDestination.inbox.title(calendar: Self.utc) == "Inbox")
        #expect(CaptureDestination.day("2026-09-28").title(calendar: Self.utc) == "Mon 28")
        #expect(CaptureDestination.slot(Self.slot).title(calendar: Self.utc) == "Mon 28, 14:00")
    }

    @Test func aDayThatDoesNotParseIsShownAsItIs() {
        #expect(CaptureDestination.day("28-09-2026").title(calendar: Self.utc) == "28-09-2026")
    }
}

/// The last kind a capture used, as UserDefaults keeps it (spec §4,
/// `omakase.capture.area`).
struct StoredCaptureAreaTests {
    @Test func aStoredRawValueReadsBackAsItsKind() {
        #expect(TaskArea(storedRaw: "study") == .study)
        #expect(TaskArea(storedRaw: "personal") == .life)
    }

    @Test(arguments: [nil, "", "bogus"] as [String?])
    func aMissingOrUnknownValueIsWork(raw: String?) {
        #expect(TaskArea(storedRaw: raw) == .work)
    }
}
