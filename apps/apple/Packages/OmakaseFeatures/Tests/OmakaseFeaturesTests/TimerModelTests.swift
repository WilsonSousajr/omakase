import Foundation
import Testing

@testable import OmakaseFeatures

/// A named fake for the timer's effects: what was saved, recorded, notified.
@MainActor
final class RecordingTimerEffects {
    private(set) var saved: [PomodoroState] = []
    private(set) var recorded: [CompletedPhase] = []
    private(set) var notified: [Date?] = []

    var actions: TimerModel.Actions {
        TimerModel.Actions(
            save: { [unowned self] in saved.append($0) },
            record: { [unowned self] in recorded.append($0) },
            notify: { [unowned self] date, _ in notified.append(date) })
    }
}

@MainActor
struct TimerModelTests {
    let effects = RecordingTimerEffects()
    let clock = Clock(Date(timeIntervalSince1970: 1_772_874_000))  // 2026-03-07 09:00 UTC
    let settings = PomodoroSettings(workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, beforeLongBreak: 4)

    func model(_ state: PomodoroState = .idle) -> TimerModel {
        let (clock, settings) = (self.clock, self.settings)
        return TimerModel(
            state: state, settings: { settings }, blockFor: { $0 == "t1" ? "b1" : nil }, actions: effects.actions,
            clock: { clock.now })
    }

    @Test func startingFocusesTheTaskOnItsBlockAndSchedulesTheEnd() {
        let timer = model()
        timer.start(taskID: "t1")
        #expect(timer.state.status == .running && timer.state.taskID == "t1" && timer.state.blockID == "b1")
        #expect(effects.notified == [clock.now.addingTimeInterval(1500)])
        #expect(effects.saved.last == timer.state)
    }

    @Test func pausingCancelsTheNotificationAndResumingReschedulesIt() {
        let timer = model()
        timer.start(taskID: "t1")
        clock.now = clock.now.addingTimeInterval(600)
        timer.pause()
        clock.now = clock.now.addingTimeInterval(300)
        timer.resume()
        #expect(effects.notified.count == 3 && effects.notified[1] == nil)
        #expect(effects.notified[2] == clock.now.addingTimeInterval(900))
    }

    @Test func aTickAfterTheEndRecordsTheSessionAndWaits() {
        let timer = model()
        timer.start(taskID: "t1")
        clock.now = clock.now.addingTimeInterval(1500)
        timer.tick()
        #expect(effects.recorded.map(\.completed) == [true] && effects.recorded.first?.blockID == "b1")
        #expect(timer.state.status == .idle && timer.state.phase == .shortBreak)
        #expect(timer.lastFinished?.phase == .focus)
    }

    @Test func aTickBeforeTheEndDoesNothing() {
        let timer = model()
        timer.start(taskID: "t1")
        clock.now = clock.now.addingTimeInterval(60)
        timer.tick()
        #expect(effects.recorded.isEmpty && timer.state.status == .running)
    }

    @Test func aTimerDueWhileTheAppWasQuitFinishesOnLaunch() {
        var state = PomodoroEngine.start(
            .idle, phase: .focus, taskID: "t1", blockID: "b1", settings: settings, now: clock.now)
        state.startedAt = clock.now.addingTimeInterval(-4 * 3600)
        let timer = model(state)
        #expect(effects.recorded.first?.endedAt == clock.now.addingTimeInterval(-4 * 3600 + 1500))
        #expect(timer.state.status == .idle)
    }

    @Test func skippingRecordsElapsedFocusAndCancelsTheNotification() {
        let timer = model()
        timer.start(taskID: "t1")
        clock.now = clock.now.addingTimeInterval(600)
        timer.skip()
        #expect(effects.recorded.map(\.completed) == [false] && effects.notified.last == .some(nil))
        #expect(timer.lastFinished == nil)
    }

    @Test func aBreakKeepsTheFocusTask() {
        let timer = model()
        timer.start(taskID: "t1")
        clock.now = clock.now.addingTimeInterval(1500)
        timer.tick()
        timer.start(taskID: nil)
        #expect(timer.state.phase == .shortBreak && timer.state.taskID == "t1")
    }

    @Test func theDisplayShowsMinutesAndSeconds() {
        let timer = model()
        #expect(timer.remainingText == "25:00")
        timer.start(taskID: "t1")
        clock.now = clock.now.addingTimeInterval(78)
        #expect(timer.remainingText == "23:42")
        #expect(abs(timer.progress - 78.0 / 1500) < 1e-9)
    }

    @Test func dismissingTheFinishedPhaseClearsIt() {
        let timer = model()
        timer.start(taskID: "t1")
        clock.now = clock.now.addingTimeInterval(1500)
        timer.tick()
        timer.dismissFinished()
        #expect(timer.lastFinished == nil)
    }
}
