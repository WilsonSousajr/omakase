import Foundation
import Testing

@testable import OmakaseFeatures

struct SessionPromptTests {
    let start = Date(timeIntervalSince1970: 1_772_874_000)

    func finished(_ phase: TimerPhase = .focus, block: String? = "b1", completed: Bool = true) -> CompletedPhase {
        CompletedPhase(
            phase: phase, taskID: "t1", blockID: block, startedAt: start, endedAt: start.addingTimeInterval(1500),
            minutes: 25, completed: completed)
    }

    @Test func aFinishedFocusOnABlockAsksWithCheckedSubtasksPrefilled() {
        let prompt = SessionPrompt.make(for: finished(), taskTitle: "Essay", doneSubtasks: ["Outline", "Intro"])
        #expect(prompt == SessionPrompt(blockID: "b1", taskTitle: "Essay", prefill: "✓ Outline\n✓ Intro"))
    }

    @Test func noBlockMeansNoPrompt() {
        // Decided with the user: the session is still recorded, with no prompt.
        #expect(SessionPrompt.make(for: finished(block: nil), taskTitle: "Essay", doneSubtasks: []) == nil)
    }

    @Test func breaksAndSkippedFocusDoNotAsk() {
        #expect(SessionPrompt.make(for: finished(.shortBreak), taskTitle: nil, doneSubtasks: []) == nil)
        #expect(SessionPrompt.make(for: finished(completed: false), taskTitle: "Essay", doneSubtasks: []) == nil)
        #expect(SessionPrompt.make(for: nil, taskTitle: nil, doneSubtasks: []) == nil)
    }

    @Test func submittingWritesTheRatingAndNotesToTheBlock() {
        let prompt = SessionPrompt(blockID: "b1", taskTitle: "Essay", prefill: "")
        #expect(prompt.writes(rating: 4, notes: "Drafted §2") == [.rate("b1", 4), .notes("b1", "Drafted §2")])
    }

    @Test func whatIsLeftEmptyIsNotWritten() {
        let prompt = SessionPrompt(blockID: "b1", taskTitle: "Essay", prefill: "")
        #expect(prompt.writes(rating: nil, notes: "  \n") == [])
        #expect(prompt.writes(rating: 5, notes: "") == [.rate("b1", 5)])
    }
}
