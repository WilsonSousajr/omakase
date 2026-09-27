import CoreGraphics
import Foundation
import Testing

@testable import OmakaseFeatures

/// Records what Plan asks the app for, one line per call, so a test reads
/// the writes in order.
@MainActor
final class PlanActionsRecorder {
    var calls: [String] = []

    var actions: PlanModel.Actions {
        PlanModel.Actions(
            refresh: { self.calls.append("refresh \($0.joined(separator: ","))") },
            create: { self.calls.append("create \($0) \(Self.line($1))") },
            move: { self.calls.append("move \($0) \(Self.line($1))") },
            delete: { self.calls.append("delete \($0)") },
            cancelClass: { self.calls.append("cancel class \($0)") },
            restoreClass: { self.calls.append("restore class \($0)") },
            capture: { self.calls.append("capture \(Self.line($0))") })
    }

    static func line(_ placement: PlanPlacement) -> String {
        "\(placement.day) \(placement.startTime)-\(placement.endTime)"
    }
}

/// Plan's writes and range reads (#203): a drop becomes a create or a move,
/// an overlap waits for "Place anyway", and the visible days are refreshed
/// while Plan shows.
@MainActor
struct PlanModelWritesTests {
    let day = "2026-09-26"
    let recorder = PlanActionsRecorder()

    func model(mode: PlanModel.Mode = .day) -> PlanModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return PlanModel(mode: mode, calendar: PlanModel.weekCalendar(calendar), actions: recorder.actions) {
            "2026-09-26"
        }
    }

    func offset(_ hour: Int, _ minute: Int = 0) -> CGFloat {
        CalendarLayout.standard.offset(forMinutes: hour * 60 + minute)
    }

    func block(_ id: String, _ start: Int, _ end: Int, title: String = "Essay") -> CalendarItem {
        CalendarItem(id: id, day: "2026-09-26", start: start, end: end, title: title, kind: .block)
    }

    @Test func showingPlanRefreshesTheVisibleDays() {
        let plan = model(mode: .week)
        plan.show()
        #expect(
            recorder.calls == ["refresh 2026-09-21,2026-09-22,2026-09-23,2026-09-24,2026-09-25,2026-09-26,2026-09-27"])
    }

    @Test func aCatchUpRefreshesOnlyWhilePlanShows() {
        let plan = model()
        plan.caughtUp()
        plan.show()
        plan.caughtUp()
        plan.hide()
        plan.caughtUp()
        #expect(recorder.calls == ["refresh 2026-09-26", "refresh 2026-09-26"])
    }

    @Test func movingTheRangeRefreshesTheNewDays() {
        let plan = model()
        plan.next()
        plan.refreshRange()
        #expect(recorder.calls == ["refresh 2026-09-27"])
    }

    @Test func aTaskDroppedOnTenCreatesAnHourBlock() {
        let accepted = model().drop("task:t1", day: day, offset: offset(10), items: [])
        #expect(accepted)
        #expect(recorder.calls == ["create t1 2026-09-26 10:00:00-11:00:00"])
    }

    @Test func aDropThatIsNotAPlanPayloadIsRefused() {
        #expect(!model().drop("t1", day: day, offset: offset(10), items: []))
        #expect(recorder.calls.isEmpty)
    }

    @Test func aTaskDroppedWithNoRoomLeftIsRefused() {
        #expect(!model().drop("task:t1", day: day, offset: offset(23), items: []))
        #expect(recorder.calls.isEmpty)
    }

    @Test func aBlockDroppedOnAnotherDayMovesThere() {
        let accepted = model().drop("block:b1", day: "2026-09-27", offset: offset(14), items: [block("b1", 540, 630)])
        #expect(accepted)
        #expect(recorder.calls == ["move b1 2026-09-27 14:00:00-15:30:00"])
    }

    @Test func aBlockThatIsNotOnTheGridIsRefused() {
        #expect(!model().drop("block:gone", day: day, offset: offset(14), items: [block("b1", 540, 630)]))
        #expect(recorder.calls.isEmpty)
    }

    @Test func aBlockDroppedWhereItWasWritesNothing() {
        #expect(model().drop("block:b1", day: day, offset: offset(9), items: [block("b1", 540, 630)]))
        #expect(recorder.calls.isEmpty)
    }

    @Test func anOverlappingDropAsksBeforeWriting() throws {
        let plan = model()
        #expect(plan.drop("task:t1", day: day, offset: offset(10), items: [block("b1", 630, 690)]))
        #expect(recorder.calls.isEmpty)
        let pending = try #require(plan.pending)
        #expect(pending.question == "Overlaps Essay. Place anyway?")
        #expect(pending.target == .task("t1"))
    }

    @Test func placingAnywayWritesTheDrop() {
        let plan = model()
        _ = plan.drop("task:t1", day: day, offset: offset(10), items: [block("b1", 630, 690)])
        plan.confirmPending()
        #expect(recorder.calls == ["create t1 2026-09-26 10:00:00-11:00:00"])
        #expect(plan.pending == nil)
    }

    @Test func cancellingTheQuestionWritesNothing() {
        let plan = model()
        _ = plan.drop("task:t1", day: day, offset: offset(10), items: [block("b1", 630, 690)])
        plan.cancelPending()
        plan.confirmPending()
        #expect(recorder.calls.isEmpty)
        #expect(plan.pending == nil)
    }

    @Test func aMovedBlockDoesNotAskAboutItself() {
        let plan = model()
        _ = plan.drop("block:b1", day: day, offset: offset(9, 30), items: [block("b1", 540, 630)])
        #expect(plan.pending == nil)
        #expect(recorder.calls == ["move b1 2026-09-26 09:30:00-11:00:00"])
    }

    @Test func aMoveOntoAnotherBlockAsks() {
        let plan = model()
        let items = [block("b1", 540, 600), block("b2", 660, 720, title: "Review PR")]
        _ = plan.drop("block:b1", day: day, offset: offset(10, 30), items: items)
        #expect(plan.pending?.question == "Overlaps Review PR. Place anyway?")
        plan.confirmPending()
        #expect(recorder.calls == ["move b1 2026-09-26 10:30:00-11:30:00"])
    }

    @Test func resizingABlockMovesItsEnd() {
        let item = block("b1", 600, 660)
        model().resize(item, bottom: offset(11, 30), items: [item])
        #expect(recorder.calls == ["move b1 2026-09-26 10:00:00-11:30:00"])
    }

    @Test func aResizeIntoAnotherBlockAsks() {
        let plan = model()
        let item = block("b1", 600, 660)
        plan.resize(item, bottom: offset(12), items: [item, block("b2", 690, 750, title: "Review PR")])
        #expect(plan.pending?.question == "Overlaps Review PR. Place anyway?")
        #expect(recorder.calls.isEmpty)
    }

    @Test func aResizeToTheSameEndWritesNothing() {
        let item = block("b1", 600, 660)
        model().resize(item, bottom: offset(11), items: [item])
        #expect(recorder.calls.isEmpty)
    }

    @Test func deletingABlockAsksTheAppToDeleteIt() {
        model().deleteBlock("b1")
        #expect(recorder.calls == ["delete b1"])
    }

    // MARK: A drawn slot (spec §9, #264)

    @Test func aSlotDrawnOnTheGridOpensCaptureWithIt() {
        model().drawSlot(day: day, from: offset(15), to: offset(14))
        #expect(recorder.calls == ["capture 2026-09-26 14:00:00-15:00:00"])
    }

    @Test func aSlotDrawnOverABlockOpensCaptureWithoutAsking() {
        let plan = model()
        plan.drawSlot(day: day, from: offset(13), to: offset(16))
        #expect(plan.pending == nil)
        #expect(recorder.calls == ["capture 2026-09-26 13:00:00-16:00:00"])
    }

    @Test func aBareClickOnTheGridOpensNothing() {
        model().drawSlot(day: day, from: offset(14), to: offset(14) + 1)
        #expect(recorder.calls.isEmpty)
    }

    @Test func withoutActionsADropStillAnswers() {
        let plan = PlanModel { "2026-09-26" }
        plan.show()
        plan.deleteBlock("b1")
        plan.drawSlot(day: day, from: offset(14), to: offset(15))
        #expect(plan.drop("task:t1", day: day, offset: offset(10), items: []))
        #expect(plan.drop("block:b1", day: day, offset: offset(12), items: [block("b1", 600, 660)]))
    }
}
