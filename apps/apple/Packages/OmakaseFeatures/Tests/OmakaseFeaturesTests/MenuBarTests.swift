import Foundation
import Testing

@testable import OmakaseFeatures

struct MenuBarTests {
    let slots = [
        SessionBlock.Slot(id: "a", taskID: "t1", start: "09:00:00", end: "10:00:00"),
        SessionBlock.Slot(id: "c", taskID: "t3", start: "15:00:00", end: "16:00:00"),
        SessionBlock.Slot(id: "b", taskID: "t2", start: "11:00:00", end: "12:00:00"),
    ]

    @Test func theNextBlockIsTheFirstThatStartsAfterNow() {
        #expect(MenuBar.nextBlock(in: slots, after: "10:30")?.id == "b")
        #expect(MenuBar.nextBlock(in: slots, after: "08:00")?.id == "a")
        #expect(MenuBar.nextBlock(in: slots, after: "16:00") == nil)
    }

    @Test func theLabelShowsTheCountdownOnlyWhileAPhaseIsOn() {
        var state = PomodoroState.idle
        #expect(MenuBar.label(for: state, remaining: "25:00") == nil)
        state.status = .running
        #expect(MenuBar.label(for: state, remaining: "18:42") == "18:42")
        state.status = .paused
        #expect(MenuBar.label(for: state, remaining: "18:42") == "18:42 ⏸")
    }

    @Test func aFocusEndingSuggestsABreak() {
        #expect(PhaseNotice.ending(.focus) == PhaseNotice(title: "Focus done", body: "Time for a break."))
    }

    @Test func aBreakEndingSuggestsFocus() {
        #expect(PhaseNotice.ending(.shortBreak) == PhaseNotice(title: "Break over", body: "Ready to focus?"))
        #expect(PhaseNotice.ending(.longBreak) == PhaseNotice(title: "Break over", body: "Ready to focus?"))
    }
}
