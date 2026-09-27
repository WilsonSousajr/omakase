import CoreGraphics
import Testing

@testable import OmakaseFeatures

/// A drop on the grid as a day, a start and an end (spec M4, N2): snapped to
/// 15 minutes, 60 minutes for a new block, kept inside 06:00-23:00, a move
/// keeping its length and a resize keeping at least 15 minutes.
struct PlanDropTests {
    let layout = CalendarLayout.standard
    let day = "2026-09-28"

    /// The y offset of `hour:minute` in a day column.
    func offset(_ hour: Int, _ minute: Int = 0) -> CGFloat { layout.offset(forMinutes: hour * 60 + minute) }

    func block(_ start: Int, _ end: Int, day: String = "2026-09-28") -> CalendarItem {
        CalendarItem(id: "b1", day: day, start: start, end: end, title: "Essay", kind: .block)
    }

    @Test func minutesAreWrittenAsTheServersClock() {
        #expect(PlanPlacement.clock(0) == "00:00:00")
        #expect(PlanPlacement.clock(585) == "09:45:00")
        #expect(PlanPlacement.clock(1380) == "23:00:00")
    }

    @Test func aPlacementCarriesItsClockTimes() {
        let placement = PlanPlacement(day: day, start: 600, end: 660)
        #expect((placement.startTime, placement.endTime) == ("10:00:00", "11:00:00"))
        #expect(placement.minutes == 60)
    }

    @Test func aTaskDroppedOnTenMakesAnHourFromTen() {
        #expect(
            PlanDrop.create(day: day, offset: offset(10), layout: layout)
                == PlanPlacement(day: day, start: 600, end: 660))
    }

    @Test func aDropSnapsToTheNearestQuarterHour() {
        #expect(PlanDrop.create(day: day, offset: offset(10, 7), layout: layout)?.start == 600)
        #expect(PlanDrop.create(day: day, offset: offset(10, 8), layout: layout)?.start == 615)
    }

    @Test func aDropAboveTheFirstHourStartsAtSix() {
        #expect(PlanDrop.create(day: day, offset: -40, layout: layout) == PlanPlacement(day: day, start: 360, end: 420))
    }

    @Test func aDropNearTheEndOfTheDayIsShortenedToFit() {
        #expect(PlanDrop.create(day: day, offset: offset(22, 30), layout: layout)?.end == 1380)
        #expect(
            PlanDrop.create(day: day, offset: offset(22, 45), layout: layout)
                == PlanPlacement(day: day, start: 1365, end: 1380))
    }

    @Test func aDropWithLessThanAQuarterHourLeftIsRejected() {
        #expect(PlanDrop.create(day: day, offset: offset(23), layout: layout) == nil)
        #expect(PlanDrop.create(day: day, offset: 5_000, layout: layout) == nil)
    }

    @Test func aMovedBlockKeepsItsLength() {
        let moved = PlanDrop.move(block(540, 630), day: "2026-09-29", offset: offset(14), layout: layout)
        #expect(moved == PlanPlacement(day: "2026-09-29", start: 840, end: 930))
    }

    @Test func aMoveSnapsItsStartAndKeepsAnUnsnappedLength() {
        let moved = PlanDrop.move(block(545, 590), day: day, offset: offset(10, 4), layout: layout)
        #expect(moved == PlanPlacement(day: day, start: 600, end: 645))
    }

    @Test func aMovePastTheEndOfTheDayIsPulledBackWhole() {
        let moved = PlanDrop.move(block(540, 630), day: day, offset: offset(22, 30), layout: layout)
        #expect(moved == PlanPlacement(day: day, start: 1290, end: 1380))
    }

    @Test func aMoveAboveTheFirstHourStartsAtSix() {
        #expect(PlanDrop.move(block(540, 600), day: day, offset: -10, layout: layout)?.start == 360)
    }

    @Test func aBlockLongerThanTheVisibleHoursCannotBeMoved() {
        #expect(PlanDrop.move(block(300, 1400), day: day, offset: offset(8), layout: layout) == nil)
    }

    @Test func aResizeSnapsTheEnd() {
        #expect(PlanDrop.resize(block(600, 660), bottom: offset(11, 30), layout: layout)?.end == 690)
        #expect(PlanDrop.resize(block(600, 660), bottom: offset(11, 37), layout: layout)?.end == 690)
    }

    @Test func aResizeKeepsTheDayAndStart() {
        let resized = PlanDrop.resize(block(600, 660), bottom: offset(12), layout: layout)
        #expect(resized == PlanPlacement(day: day, start: 600, end: 720))
    }

    @Test func aResizeAboveTheStartLeavesAQuarterHour() {
        #expect(PlanDrop.resize(block(600, 660), bottom: offset(9), layout: layout)?.end == 615)
        #expect(PlanDrop.resize(block(600, 660), bottom: offset(10), layout: layout)?.end == 615)
    }

    @Test func aResizeStopsAtElevenPM() {
        #expect(PlanDrop.resize(block(1320, 1350), bottom: 5_000, layout: layout)?.end == 1380)
    }

    @Test func aResizeThatWouldCrossMidnightIsRejected() {
        #expect(PlanDrop.resize(block(1430, 1435), bottom: offset(23), layout: layout) == nil)
    }
}
