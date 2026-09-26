import Testing

@testable import OmakaseFeatures

/// Records each capture the model asks for, in order.
@MainActor
final class CaptureRecorder {
    private(set) var captured: [(title: String, destination: CaptureDestination)] = []

    var actions: CaptureModel.Actions {
        CaptureModel.Actions(capture: { [self] title, destination in captured.append((title, destination)) })
    }
}

@MainActor
struct CaptureModelTests {
    @Test func enterSavesTheTrimmedTitleForToday() {
        let recorder = CaptureRecorder()
        let model = CaptureModel(actions: recorder.actions)
        model.draft = "  Email the advisor \n"
        #expect(model.save(to: .today))
        #expect(recorder.captured.map(\.title) == ["Email the advisor"])
        #expect(recorder.captured.map(\.destination) == [.today])
    }

    @Test func commandEnterSavesToTheInbox() {
        let recorder = CaptureRecorder()
        let model = CaptureModel(actions: recorder.actions)
        model.draft = "Buy stamps"
        #expect(model.save(to: .inbox))
        #expect(recorder.captured.map(\.destination) == [.inbox])
    }

    @Test(arguments: ["", "   ", "\n\t "])
    func anEmptyTitleSavesNothing(draft: String) {
        let recorder = CaptureRecorder()
        let model = CaptureModel(actions: recorder.actions)
        model.draft = draft
        #expect(!model.save(to: .today))
        #expect(recorder.captured.isEmpty)
    }

    @Test func theDraftClearsAfterASave() {
        let model = CaptureModel(actions: CaptureRecorder().actions)
        model.draft = "Buy stamps"
        model.save(to: .today)
        #expect(model.draft.isEmpty)
    }

    @Test func dismissClearsTheDraftWithoutSaving() {
        let recorder = CaptureRecorder()
        let model = CaptureModel(actions: recorder.actions)
        model.draft = "Half a thought"
        model.dismiss()
        #expect(model.draft.isEmpty)
        #expect(recorder.captured.isEmpty)
    }

    @Test func theFooterSaysWhereEnterSaves() {
        #expect(CaptureModel.enterDestination == .today)
        #expect(CaptureDestination.today.title == "Today")
        #expect(CaptureDestination.inbox.title == "Inbox")
        #expect(CaptureModel.hint == "⏎ Today · ⌘⏎ Inbox · ⎋ dismiss")
    }
}
