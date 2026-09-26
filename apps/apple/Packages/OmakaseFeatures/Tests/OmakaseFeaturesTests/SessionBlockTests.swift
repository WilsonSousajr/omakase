import Testing

@testable import OmakaseFeatures

struct SessionBlockTests {
    let blocks = [
        SessionBlock.Slot(id: "early", taskID: "t1", start: "08:00:00", end: "09:00:00"),
        SessionBlock.Slot(id: "late", taskID: "t1", start: "14:00:00", end: "15:30:00"),
        SessionBlock.Slot(id: "other", taskID: "t2", start: "10:00:00", end: "11:00:00"),
    ]

    @Test func theBlockCoveringNowWins() {
        #expect(SessionBlock.pick(for: "t1", in: blocks, at: "14:20") == "late")
    }

    @Test func otherwiseTheNextOneToday() {
        #expect(SessionBlock.pick(for: "t1", in: blocks, at: "11:00") == "late")
    }

    @Test func noBlockLeftTodayMeansNone() {
        #expect(SessionBlock.pick(for: "t1", in: blocks, at: "16:00") == nil)
        #expect(SessionBlock.pick(for: "t3", in: blocks, at: "09:30") == nil)
    }
}
