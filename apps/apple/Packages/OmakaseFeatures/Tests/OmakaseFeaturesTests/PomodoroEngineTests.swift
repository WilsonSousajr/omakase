import Foundation
import Testing

@testable import OmakaseFeatures

struct PomodoroEngineTests {
    let settings = PomodoroSettings(workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, beforeLongBreak: 2)
    let start = Date(timeIntervalSince1970: 1_772_874_000)  // 2026-03-07 09:00 UTC

    func running(_ phase: TimerPhase = .focus, focuses: Int = 0) -> PomodoroState {
        var state = PomodoroState.idle
        state.completedFocuses = focuses
        return PomodoroEngine.start(state, phase: phase, taskID: "t1", blockID: "b1", settings: settings, now: start)
    }

    @Test func aStartedFocusRunsForTheWorkMinutes() {
        let state = running()
        #expect(state.status == .running && state.phase == .focus && state.taskID == "t1")
        #expect(PomodoroEngine.remaining(state, now: start.addingTimeInterval(60)) == 24 * 60)
        #expect(abs(PomodoroEngine.progress(state, now: start.addingTimeInterval(750)) - 0.5) < 1e-9)
    }

    @Test func pausedTimeDoesNotCount() {
        var state = PomodoroEngine.pause(running(), now: start.addingTimeInterval(600))
        #expect(state.status == .paused)
        #expect(PomodoroEngine.remaining(state, now: start.addingTimeInterval(3600)) == 15 * 60)
        state = PomodoroEngine.resume(state, now: start.addingTimeInterval(1200))
        #expect(PomodoroEngine.remaining(state, now: start.addingTimeInterval(1260)) == 14 * 60)
    }

    @Test func aTimerIsDueOnlyOnceItRunsOut() {
        let state = running()
        #expect(!PomodoroEngine.isDue(state, now: start.addingTimeInterval(1499)))
        #expect(PomodoroEngine.isDue(state, now: start.addingTimeInterval(1500)))
        #expect(!PomodoroEngine.isDue(PomodoroEngine.pause(state, now: start), now: start.addingTimeInterval(9999)))
    }

    @Test func aFinishedFocusIsRecordedAndABreakWaits() {
        let (next, done) = PomodoroEngine.finish(running(), now: start.addingTimeInterval(1500), settings: settings)
        #expect(done == CompletedPhase(
            phase: .focus, taskID: "t1", blockID: "b1", startedAt: start,
            endedAt: start.addingTimeInterval(1500), minutes: 25, completed: true))
        #expect(next.status == .idle && next.phase == .shortBreak && next.completedFocuses == 1)
        #expect(next.plannedSeconds == 5 * 60 && next.taskID == "t1")
    }

    @Test func everyNthFocusEarnsALongBreak() {
        let (next, _) = PomodoroEngine.finish(running(focuses: 1), now: start.addingTimeInterval(1500), settings: settings)
        #expect(next.phase == .longBreak && next.plannedSeconds == 15 * 60)
    }

    @Test func aLongBreakStartsANewCycle() {
        let (next, done) = PomodoroEngine.finish(
            running(.longBreak, focuses: 2), now: start.addingTimeInterval(900), settings: settings)
        #expect(next.phase == .focus && next.completedFocuses == 0 && done?.completed == true)
    }

    @Test func aTimerThatRanOutWhileQuitEndsWhenItWasDue() {
        // The spec: a running pomodoro survives a quit; relaunching hours later
        // records the session as it ran, not as long as the app was closed.
        let (_, done) = PomodoroEngine.finish(running(), now: start.addingTimeInterval(4 * 3600), settings: settings)
        #expect(done?.endedAt == start.addingTimeInterval(1500) && done?.minutes == 25)
    }

    @Test func aPausedPhaseEndsLaterByThePause() {
        var state = PomodoroEngine.pause(running(), now: start.addingTimeInterval(600))
        state = PomodoroEngine.resume(state, now: start.addingTimeInterval(900))
        let (_, done) = PomodoroEngine.finish(state, now: start.addingTimeInterval(9000), settings: settings)
        #expect(done?.endedAt == start.addingTimeInterval(1800))
    }

    @Test func aSkippedFocusRecordsItsElapsedTimeAsIncomplete() {
        let (next, done) = PomodoroEngine.skip(running(), now: start.addingTimeInterval(10 * 60 + 30), settings: settings)
        #expect(done?.completed == false && done?.minutes == 10 && done?.endedAt == start.addingTimeInterval(630))
        #expect(next.phase == .focus && next.status == .idle && next.completedFocuses == 0)
    }

    @Test func aFocusSkippedWithinAMinuteRecordsNothing() {
        let (_, done) = PomodoroEngine.skip(running(), now: start.addingTimeInterval(59), settings: settings)
        #expect(done == nil)
    }

    @Test func aSkippedBreakRecordsNothingAndFocusWaits() {
        let (next, done) = PomodoroEngine.skip(running(.shortBreak, focuses: 1), now: start.addingTimeInterval(60), settings: settings)
        #expect(done == nil && next.phase == .focus && next.completedFocuses == 1)
    }

    @Test func theStateSurvivesEncoding() throws {
        let state = PomodoroEngine.pause(running(), now: start.addingTimeInterval(60))
        let decoded = try JSONDecoder().decode(PomodoroState.self, from: JSONEncoder().encode(state))
        #expect(decoded == state)
    }

    @Test func settingsDefaultToTheClassicPomodoro() {
        #expect(PomodoroSettings.standard == PomodoroSettings(
            workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, beforeLongBreak: 4))
    }

    @Test func eachPhaseHasTheServersSessionType() {
        #expect(TimerPhase.allCases.map(\.sessionType) == ["focus", "short_break", "long_break"])
    }
}
