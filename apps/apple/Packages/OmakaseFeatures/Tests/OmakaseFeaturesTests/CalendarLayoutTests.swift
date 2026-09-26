import CoreGraphics
import Testing

@testable import OmakaseFeatures

/// The grid's geometry, pure (spec M4, Grid): 06:00-23:00 at 52 pt an hour,
/// 15-minute snapping, clipping, and lanes for overlapping blocks.
struct CalendarLayoutTests {
    let layout = CalendarLayout.standard

    func item(_ id: String, _ start: Int, _ end: Int, kind: CalendarItem.Kind = .block, day: String = "d")
        -> CalendarItem
    {
        CalendarItem(id: id, day: day, start: start, end: end, title: id, kind: kind)
    }

    @Test func theGridRunsFromSixToElevenAtFiftyTwoPointsAnHour() {
        #expect(layout.firstHour == 6)
        #expect(layout.lastHour == 23)
        #expect(layout.hourHeight == 52)
        #expect(layout.hours == Array(6..<23))
        #expect(layout.totalHeight == CGFloat(17 * 52))
    }

    @Test func aTimeIsItsDistanceFromTheFirstHour() {
        #expect(layout.y(forMinutes: 6 * 60) == 0)
        #expect(layout.y(forMinutes: 8 * 60) == 104)
        #expect(layout.y(forMinutes: 8 * 60 + 30) == 130)
        #expect(layout.y(forMinutes: 23 * 60) == layout.totalHeight)
    }

    @Test func aPointSnapsToTheNearestQuarterHour() {
        let quarter = layout.hourHeight / 4
        #expect(layout.minutes(forY: 104) == 480)
        #expect(layout.minutes(forY: 104 + quarter * 0.49) == 480)
        #expect(layout.minutes(forY: 104 + quarter * 0.5) == 495)
        #expect(layout.minutes(forY: 104 + quarter * 1.4) == 495)
    }

    @Test func aPointOutsideTheGridClampsToItsEdges() {
        #expect(layout.minutes(forY: -40) == 360)
        #expect(layout.minutes(forY: 0) == 360)
        #expect(layout.minutes(forY: layout.totalHeight) == 1380)
        #expect(layout.minutes(forY: layout.totalHeight + 500) == 1380)
    }

    @Test func anItemIsPlacedByItsStartAndLength() {
        #expect(layout.band(for: item("a", 540, 630)) == CalendarBand(y: 156, height: 78))
    }

    @Test func aShortItemKeepsAVisibleHeight() {
        let band = layout.band(for: item("a", 540, 545))
        #expect(band?.height == CalendarLayout.minimumHeight)
    }

    @Test func anItemIsClippedToTheVisibleHours() {
        #expect(layout.band(for: item("early", 300, 420)) == CalendarBand(y: 0, height: 52))
        #expect(layout.band(for: item("late", 22 * 60, 24 * 60 - 1)) == CalendarBand(y: 16 * 52, height: 52))
    }

    @Test func anItemWhollyOutsideTheVisibleHoursIsNotDrawn() {
        #expect(layout.band(for: item("night", 60, 300)) == nil)
        #expect(layout.band(for: item("edge", 300, 360)) == nil)
        #expect(layout.band(for: item("after", 23 * 60, 23 * 60 + 30)) == nil)
    }

    @Test func threeOverlappingBlocksTakeThreeLanes() {
        let lanes = CalendarLayout.lanes(for: [item("a", 540, 660), item("b", 570, 630), item("c", 600, 690)])
        #expect(lanes["a"] == CalendarLane(index: 0, count: 3))
        #expect(lanes["b"] == CalendarLane(index: 1, count: 3))
        #expect(lanes["c"] == CalendarLane(index: 2, count: 3))
    }

    @Test func touchingBlocksDoNotOverlap() {
        let lanes = CalendarLayout.lanes(for: [item("a", 540, 600), item("b", 600, 660)])
        #expect(lanes["a"] == CalendarLane(index: 0, count: 1))
        #expect(lanes["b"] == CalendarLane(index: 0, count: 1))
    }

    @Test func aFreedLaneIsReusedWithinTheSameCluster() {
        let lanes = CalendarLayout.lanes(for: [item("a", 540, 600), item("b", 540, 700), item("c", 610, 650)])
        #expect(lanes["a"] == CalendarLane(index: 0, count: 2))
        #expect(lanes["b"] == CalendarLane(index: 1, count: 2))
        #expect(lanes["c"] == CalendarLane(index: 0, count: 2))
    }

    @Test func blocksOnDifferentDaysDoNotShareLanes() {
        let lanes = CalendarLayout.lanes(for: [item("a", 540, 600, day: "d1"), item("b", 540, 600, day: "d2")])
        #expect(lanes["a"] == CalendarLane(index: 0, count: 1))
        #expect(lanes["b"] == CalendarLane(index: 0, count: 1))
    }

    @Test func classesAndSessionsAreNotLanedWithBlocks() {
        let lanes = CalendarLayout.lanes(for: [
            item("block", 540, 600), item("class", 540, 600, kind: .classOccurrence),
            item("session", 540, 600, kind: .focusSession),
        ])
        #expect(lanes == ["block": CalendarLane(index: 0, count: 1)])
    }

    @Test func aBlockShareOfTheColumnLeavesTheSessionLaneFree() {
        let width: CGFloat = 206
        let usable = width - CalendarLayout.sessionLaneWidth - CalendarLayout.laneGap
        #expect(CalendarLayout.blockSpan(lane: nil, width: width) == CalendarSpan(x: 0, width: usable - 2))
        let second = CalendarLayout.blockSpan(lane: CalendarLane(index: 1, count: 2), width: width)
        #expect(second == CalendarSpan(x: usable / 2, width: usable / 2 - CalendarLayout.laneGap))
    }

    @Test func aSessionRunsDownTheColumnsTrailingEdge() {
        let span = CalendarLayout.sessionSpan(width: 200)
        #expect(span == CalendarSpan(x: 200 - CalendarLayout.sessionLaneWidth, width: CalendarLayout.sessionLaneWidth))
    }
}
