import Testing

@testable import OmakaseFeatures

/// What a drag on Plan carries, as the String SwiftUI transfers: a task from
/// the column or a block on the grid, told apart by a prefix (#203).
struct PlanDragPayloadTests {
    @Test func aTaskAndABlockAreWrittenWithTheirPrefix() {
        #expect(PlanDragPayload.task("t1").text == "task:t1")
        #expect(PlanDragPayload.block("local-9").text == "block:local-9")
    }

    @Test func eachReadsBackFromItsText() {
        #expect(PlanDragPayload("task:t1") == .task("t1"))
        #expect(PlanDragPayload("block:local-9") == .block("local-9"))
    }

    @Test func anIdKeepsAnyColonsAfterThePrefix() {
        #expect(PlanDragPayload("block:c1:2026-09-28") == .block("c1:2026-09-28"))
    }

    @Test func textThatIsNotAPlanPayloadIsRejected() {
        #expect(PlanDragPayload("t1") == nil)
        #expect(PlanDragPayload("class:c1") == nil)
        #expect(PlanDragPayload("task:") == nil)
        #expect(PlanDragPayload("") == nil)
    }
}
