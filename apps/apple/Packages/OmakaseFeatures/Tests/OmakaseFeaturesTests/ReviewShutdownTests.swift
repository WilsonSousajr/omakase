import Foundation
import OmakaseStore
import Testing

@testable import OmakaseFeatures

extension ReviewModelTests {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}

/// Rollover choices, Shut down and Reopen (#179), against the fake writes.
@MainActor
struct ReviewShutdownTests {
    let recorder = RecordingReviewActions()
    let debounce = ManualDebounce()
    let day = "2026-03-07"

    func model(loading values: ReviewValues = .empty) -> ReviewModel {
        let model = ReviewModel(actions: recorder.actions, schedule: debounce.schedule, calendar: ReviewModelTests.utc)
        model.load(day: day, values: values)
        return model
    }

    @Test func everyUnfinishedTaskRollsToTheDayAfterTheReviewsDayByDefault() throws {
        let model = model()
        #expect(model.rollover(for: "t1") == .tomorrow)
        model.shutDown(unfinished: ["t1", "t2"])
        let sent = try #require(recorder.shutDowns.first)
        #expect(sent.day == day)
        #expect(
            sent.rollovers == [
                TaskRollover(taskID: "t1", day: "2026-03-08"), TaskRollover(taskID: "t2", day: "2026-03-08"),
            ])
    }

    @Test func changedChoicesAreSent() throws {
        let model = model()
        let picked = try #require(DayString.date("2026-03-12", calendar: ReviewModelTests.utc))
        model.chooseRollover(.backlog, for: "t1")
        model.chooseRollover(.date(picked), for: "t2")
        model.shutDown(unfinished: ["t1", "t2", "t3"])
        #expect(
            recorder.shutDowns.first?.rollovers == [
                TaskRollover(taskID: "t1", day: nil), TaskRollover(taskID: "t2", day: "2026-03-12"),
                TaskRollover(taskID: "t3", day: "2026-03-08"),
            ])
    }

    @Test func shuttingDownClosesTheDayAndSendsTheDraft() {
        let model = model(loading: ReviewValues(rating: 4, energy: 2, win: "Shipped", isShutdown: false))
        model.shutDown(unfinished: [])
        #expect(model.isShutdown)
        let closed = ReviewValues(rating: 4, energy: 2, win: "Shipped", isShutdown: true)
        #expect(recorder.shutDowns.first?.values == closed)
        #expect(recorder.saved.isEmpty)
    }

    @Test func aWaitingEditIsSentWithTheShutdownAndNotSavedAgain() {
        let model = model()
        model.setWin("Typed just before")
        model.shutDown(unfinished: [])
        debounce.pauseEnds()
        #expect(recorder.shutDowns.first?.values.win == "Typed just before")
        #expect(recorder.saved.isEmpty)
    }

    @Test func reopeningSavesTheDayOpenAtOnce() {
        let model = model(loading: ReviewValues(rating: 3, energy: nil, win: "", isShutdown: true))
        model.reopen()
        #expect(!model.isShutdown)
        #expect(recorder.saved.map(\.values) == [ReviewValues(rating: 3, energy: nil, win: "", isShutdown: false)])
    }

    @Test func aReviewAlreadyShutDownLoadsClosed() {
        #expect(model(loading: ReviewValues(rating: nil, energy: nil, win: "", isShutdown: true)).isShutdown)
        #expect(!model().isShutdown)
    }

    @Test func shuttingDownResetsTheChoices() {
        let model = model()
        model.chooseRollover(.backlog, for: "t1")
        model.shutDown(unfinished: ["t1"])
        #expect(model.rollover(for: "t1") == .tomorrow)
    }

    @Test func aNewDayForgetsTheOldDaysChoices() {
        let model = model()
        model.chooseRollover(.backlog, for: "t1")
        model.load(day: "2026-03-08", values: .empty)
        #expect(model.rollover(for: "t1") == .tomorrow)
    }

    @Test func nothingIsSentBeforeADayLoads() {
        let model = ReviewModel(actions: recorder.actions, schedule: debounce.schedule)
        model.shutDown(unfinished: ["t1"])
        model.reopen()
        #expect(recorder.shutDowns.isEmpty && recorder.saved.isEmpty)
    }

    @Test func eachChoiceHasAShortLabel() throws {
        let model = model()
        let picked = try #require(DayString.date("2026-03-12", calendar: ReviewModelTests.utc))
        #expect(model.rolloverLabel(for: "t1") == "Tomorrow")
        model.chooseRollover(.backlog, for: "t1")
        #expect(model.rolloverLabel(for: "t1") == "Backlog")
        model.chooseRollover(.date(picked), for: "t1")
        #expect(model.rolloverLabel(for: "t1") == "Thu 12")
        model.chooseRollover(.today, for: "t1")
        #expect(model.rolloverLabel(for: "t1") == "Today")
    }

    @Test func theShutdownHintCountsTheTasksItMoves() {
        #expect(ReviewModel.shutDownHint(moving: 0) == "Closes the day")
        #expect(ReviewModel.shutDownHint(moving: 1) == "Moves 1 task and closes the day")
        #expect(ReviewModel.shutDownHint(moving: 3) == "Moves 3 tasks and closes the day")
        #expect(ReviewModel.shutdownLine == "Great work today. Time to rest.")
    }
}
