import CoreGraphics
import Testing

@testable import OmakaseFeatures

/// The grid's geometry, pure (spec M4, Grid): 06:00-23:00 at 52 pt an hour,
/// 15-minute snapping, clipping, and lanes for overlapping blocks.
struct CalendarLayoutTests {
    typealias Item = CalendarItem
    let layout = CalendarLayout.standard

    func item(_ id: String, _ start: Int, _ end: Int, kind: CalendarItem.Kind = .block, day: String = "d") -> Item {
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
        #expect(layout.offset(forMinutes: 6 * 60) == 0)
        #expect(layout.offset(forMinutes: 8 * 60) == 104)
        #expect(layout.offset(forMinutes: 8 * 60 + 30) == 130)
        #expect(layout.offset(forMinutes: 23 * 60) == layout.totalHeight)
    }

    @Test func aPointSnapsToTheNearestQuarterHour() {
        let quarter = layout.hourHeight / 4
        #expect(layout.minutes(forOffset: 104) == 480)
        #expect(layout.minutes(forOffset: 104 + quarter * 0.49) == 480)
        #expect(layout.minutes(forOffset: 104 + quarter * 0.5) == 495)
        #expect(layout.minutes(forOffset: 104 + quarter * 1.4) == 495)
    }

    @Test func aPointOutsideTheGridClampsToItsEdges() {
        #expect(layout.minutes(forOffset: -40) == 360)
        #expect(layout.minutes(forOffset: 0) == 360)
        #expect(layout.minutes(forOffset: layout.totalHeight) == 1380)
        #expect(layout.minutes(forOffset: layout.totalHeight + 500) == 1380)
    }

    @Test func anItemIsPlacedByItsStartAndLength() {
        #expect(layout.band(for: item("a", 540, 630)) == CalendarBand(top: 156, height: 78))
    }

    @Test func aShortItemKeepsAVisibleHeight() {
        let band = layout.band(for: item("a", 540, 545))
        #expect(band?.height == CalendarLayout.minimumHeight)
    }

    @Test func anItemIsClippedToTheVisibleHours() {
        #expect(layout.band(for: item("early", 300, 420)) == CalendarBand(top: 0, height: 52))
        #expect(layout.band(for: item("late", 22 * 60, 24 * 60 - 1)) == CalendarBand(top: 16 * 52, height: 52))
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
        #expect(CalendarLayout.blockSpan(lane: nil, width: width) == CalendarSpan(leading: 0, width: usable - 2))
        let second = CalendarLayout.blockSpan(lane: CalendarLane(index: 1, count: 2), width: width)
        #expect(second == CalendarSpan(leading: usable / 2, width: usable / 2 - CalendarLayout.laneGap))
    }

    @Test func aSessionRunsDownTheColumnsTrailingEdge() {
        let span = CalendarLayout.sessionSpan(width: 200)
        let lane = CalendarLayout.sessionLaneWidth
        #expect(span == CalendarSpan(leading: 200 - lane, width: lane))
    }

    /// The grid opened at 06:00 because the scroll to 08:00 never landed;
    /// the target is now a number the view scrolls to (#215).
    @Test func theGridOpensAtEightNotSixIssue215() {
        let minutes = layout.initialMinutes(day: "2026-09-28", today: "2026-09-27", nowMinutes: 7 * 60)
        #expect(minutes == 8 * 60)
        #expect(layout.offset(forMinutes: minutes) == 104)
    }

    @Test func todayBeforeNineStillOpensAtEight() {
        #expect(layout.initialMinutes(day: "d", today: "d", nowMinutes: 9 * 60) == 8 * 60)
        #expect(layout.initialMinutes(day: "d", today: "d", nowMinutes: 30) == 8 * 60)
    }

    @Test func todayAfterNineOpensAnHourBeforeNow() {
        #expect(layout.initialMinutes(day: "d", today: "d", nowMinutes: 14 * 60 + 20) == 13 * 60 + 20)
    }

    @Test func aLateNowIsClampedToTheLastHour() {
        #expect(layout.initialMinutes(day: "d", today: "d", nowMinutes: 23 * 60 + 50) == 23 * 60)
    }
}
