import Foundation
import Testing

@testable import OmakaseFeatures

/// The sidebar's now strip (spec §6, #260): the running or paused phase,
/// else the day's next block, else nothing.
struct NowStripTests {
    private func timer(
        _ status: PomodoroState.Status, phase: TimerPhase = .focus, taskID: String? = "t1",
        title: String? = "Outline thesis"
    ) -> NowStripTimer {
        NowStripTimer(status: status, phase: phase, remaining: "18:42", progress: 0.25, taskID: taskID, title: title)
    }

    private let next = NowStripNext(start: "14:00:00", taskID: "t2", title: "Read chapter 3")

    @Test func aRunningPhaseShowsItsRingCountdownAndTask() {
        let phase = NowStripPhase(
            phase: .focus, remaining: "18:42", progress: 0.25, title: "Outline thesis", taskID: "t1")
        #expect(NowStrip.state(timer: timer(.running), nextBlock: next) == .running(phase))
    }

    @Test func aPausedPhaseShowsTheSameDimmed() {
        let phase = NowStripPhase(
            phase: .focus, remaining: "18:42", progress: 0.25, title: "Outline thesis", taskID: "t1")
        #expect(NowStrip.state(timer: timer(.paused), nextBlock: next) == .paused(phase))
    }

    @Test func aPhaseWhoseTaskIsNotCachedReadsAsThePhase() {
        let phase = NowStripPhase(
            phase: .shortBreak, remaining: "18:42", progress: 0.25, title: "Short break", taskID: "t1")
        let state = NowStrip.state(timer: timer(.running, phase: .shortBreak, title: nil), nextBlock: nil)
        #expect(state == .running(phase))
    }

    @Test func idleWithANextBlockShowsItsStartAndTitle() {
        #expect(
            NowStrip.state(timer: timer(.idle), nextBlock: next)
                == .next(title: "Read chapter 3", start: "14:00", taskID: "t2"))
    }

    @Test func aNextBlockWithNoTaskIsAStudyBlock() {
        let studyBlock = NowStripNext(start: "09:30:00", taskID: nil, title: nil)
        #expect(
            NowStrip.state(timer: timer(.idle), nextBlock: studyBlock)
                == .next(title: "Study", start: "09:30", taskID: nil))
    }

    @Test func idleWithNoNextBlockShowsNothing() {
        #expect(NowStrip.state(timer: timer(.idle), nextBlock: nil) == .idle)
    }

    @Test func clickingOpensThePhasesTaskOrTheNextBlocks() {
        #expect(NowStrip.state(timer: timer(.running), nextBlock: next).taskID == "t1")
        #expect(NowStrip.state(timer: timer(.paused, taskID: "t9"), nextBlock: next).taskID == "t9")
        #expect(NowStrip.state(timer: timer(.idle), nextBlock: next).taskID == "t2")
        #expect(NowStrip.state(timer: timer(.idle), nextBlock: nil).taskID == nil)
    }

    @Test func aNextBlockReadsFromItsSlot() {
        let slot = SessionBlock.Slot(id: "b1", taskID: "t2", start: "14:00:00", end: "15:00:00")
        #expect(NowStripNext(slot: slot, title: "Read chapter 3") == next)
    }

    @MainActor
    @Test func theTimerReadsAsPlainValues() {
        let clock = Clock(Date(timeIntervalSince1970: 1_772_874_000))
        let effects = RecordingTimerEffects()
        let model = TimerModel(
            state: .idle, settings: { .standard }, blockFor: { _ in nil }, actions: effects.actions,
            clock: { clock.now })
        model.start(taskID: "t1")
        clock.now = clock.now.addingTimeInterval(375)
        model.tick()
        #expect(
            NowStripTimer(model, title: "Outline thesis")
                == NowStripTimer(
                    status: .running, phase: .focus, remaining: "18:45", progress: 0.25, taskID: "t1",
                    title: "Outline thesis"))
    }
}
