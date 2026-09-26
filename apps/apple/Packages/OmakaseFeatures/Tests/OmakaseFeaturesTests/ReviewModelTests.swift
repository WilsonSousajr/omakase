import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// A named fake for the app's review write: records each save.
@MainActor
final class RecordingReviewActions {
    private(set) var saved: [(day: String, values: ReviewValues)] = []

    var actions: ReviewModel.Actions {
        ReviewModel.Actions(save: { [unowned self] day, values in saved.append((day, values)) })
    }
}

/// A named fake for the debounce: holds each scheduled save until the test
/// lets the pause end, so no test waits on a clock.
@MainActor
final class ManualDebounce {
    private var waiting: [@MainActor () -> Void] = []

    var schedule: ReviewModel.Scheduler { { [unowned self] work in waiting.append(work) } }

    func pauseEnds() {
        let due = waiting
        waiting = []
        due.forEach { $0() }
    }

    /// Ends only the oldest pause, as a clock would when changes are spaced.
    func firstPauseEnds() {
        guard !waiting.isEmpty else { return }
        waiting.removeFirst()()
    }
}

@MainActor
struct ReviewModelTests {
    let recorder = RecordingReviewActions()
    let debounce = ManualDebounce()
    let day = "2026-03-07"

    func model(loading values: ReviewValues = .empty) -> ReviewModel {
        let model = ReviewModel(actions: recorder.actions, schedule: debounce.schedule)
        model.load(day: day, values: values)
        return model
    }

    @Test func settingARatingSavesOnceTheTypingPauses() {
        let model = model()
        model.chooseRating(4)
        #expect(recorder.saved.isEmpty)
        debounce.pauseEnds()
        #expect(recorder.saved.map(\.day) == [day])
        #expect(recorder.saved.first?.values.rating == 4)
    }

    @Test func rapidChangesCoalesceIntoOneSave() {
        let model = model()
        model.chooseRating(3)
        model.chooseEnergy(2)
        model.setWin("Shipped the review")
        debounce.pauseEnds()
        let expected = ReviewValues(rating: 3, energy: 2, win: "Shipped the review", isShutdown: false)
        #expect(recorder.saved.map(\.values) == [expected])
    }

    @Test func anEarlierPauseEndingSavesNothingWhileALaterChangeWaits() {
        let model = model()
        model.chooseRating(3)
        model.setWin("Still typing")
        debounce.firstPauseEnds()
        #expect(recorder.saved.isEmpty)
        debounce.firstPauseEnds()
        #expect(recorder.saved.map(\.values.win) == ["Still typing"])
    }

    @Test func anExistingReviewLoadsIntoTheDraft() {
        let stored = ReviewValues(rating: 5, energy: 3, win: "A calm day", isShutdown: false)
        #expect(model(loading: stored).draft == stored)
        #expect(recorder.saved.isEmpty)
    }

    @Test func choosingTheChosenEnergyAgainClearsItAndSavesNil() {
        let model = model(loading: ReviewValues(rating: nil, energy: 2, win: "", isShutdown: false))
        model.chooseEnergy(2)
        debounce.pauseEnds()
        #expect(recorder.saved.count == 1)
        #expect(recorder.saved.first?.values.energy == nil)
    }

    @Test func choosingTheChosenRatingAgainClearsIt() {
        let model = model(loading: ReviewValues(rating: 4, energy: nil, win: "", isShutdown: false))
        model.chooseRating(4)
        #expect(model.draft.rating == nil)
    }

    @Test func aClosedDayStaysClosedWhenTheDraftIsSaved() {
        let model = model(loading: ReviewValues(rating: nil, energy: nil, win: "", isShutdown: true))
        model.setWin("Late thought")
        debounce.pauseEnds()
        #expect(recorder.saved.first?.values.isShutdown == true)
    }

    @Test func theStoresCopyDoesNotOverwriteAnEditStillWaitingToSave() {
        let model = model()
        model.setWin("Half typed")
        model.load(day: day, values: ReviewValues(rating: 2, energy: nil, win: "", isShutdown: false))
        #expect(model.draft.win == "Half typed")
    }

    @Test func theStoresCopyLoadsOnceNothingIsWaiting() {
        let model = model()
        let synced = ReviewValues(rating: 2, energy: 1, win: "From the server", isShutdown: false)
        model.load(day: day, values: synced)
        #expect(model.draft == synced)
    }

    @Test func movingToANewDaySavesTheOldDaysEditFirst() {
        let model = model()
        model.chooseRating(5)
        model.load(day: "2026-03-08", values: .empty)
        #expect(recorder.saved.map(\.day) == [day])
        #expect(model.day == "2026-03-08" && model.draft == .empty)
        debounce.pauseEnds()
        #expect(recorder.saved.count == 1)
    }

    @Test func flushingWithNothingChangedSavesNothing() {
        model().flush()
        #expect(recorder.saved.isEmpty)
    }

    @Test func theEnergyChoicesAreLowSteadyHigh() {
        #expect(ReviewEnergy.allCases.map(\.rawValue) == [1, 2, 3])
        #expect(ReviewEnergy.allCases.map(\.title) == ["Low", "Steady", "High"])
        #expect(ReviewModel.ratings == 1...5)
    }

    @Test func theDraftReadsTheStoresReview() {
        let record = DailyReviewRecord(day: day, rating: 3, win: "Tidy", energy: 1)
        #expect(ReviewValues(record: record) == ReviewValues(rating: 3, energy: 1, win: "Tidy", isShutdown: false))
        #expect(ReviewValues(record: nil) == .empty)
    }

    @Test func theAppsDebounceRunsTheSaveAfterItsPause() async throws {
        var ran = false
        ReviewModel.afterPause(.milliseconds(1))({ ran = true })
        try await Task.sleep(for: .milliseconds(100))
        #expect(ran)
    }
}
