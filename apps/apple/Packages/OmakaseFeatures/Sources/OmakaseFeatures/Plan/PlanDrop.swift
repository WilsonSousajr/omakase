import CoreGraphics
import Foundation

/// Where a block goes: a day and its minutes since midnight, and the
/// "HH:MM:SS" the server's `TimeField`s take.
///
///     PlanPlacement(day: "2026-09-28", start: 600, end: 660).startTime   // "10:00:00"
public struct PlanPlacement: Equatable, Sendable {
    public let day: String
    public let start: Int
    public let end: Int

    public init(day: String, start: Int, end: Int) { (self.day, self.start, self.end) = (day, start, end) }

    public var startTime: String { Self.clock(start) }
    public var endTime: String { Self.clock(end) }
    public var minutes: Int { end - start }

    public static func clock(_ minutes: Int) -> String { String(format: "%02d:%02d:00", minutes / 60, minutes % 60) }
}

/// A drop or a drag on the grid as a placement, pure so the edges are tested
/// without a gesture (spec M4, N2): starts snap to 15 minutes, a new block is
/// 60 minutes, and nothing leaves 06:00-23:00 or reaches midnight. `offset`
/// is the y in the day column, as `CalendarLayout` measures it.
///
///     PlanDrop.create(day: "2026-09-28", offset: 208, layout: .standard)   // 10:00-11:00
public enum PlanDrop {
    public static let newBlockMinutes = 60
    static let midnight = 24 * 60

    /// A task dropped at `offset`: an hour from the snapped start, shortened
    /// to end by 23:00; nil when less than 15 minutes is left.
    public static func create(day: String, offset: CGFloat, layout: CalendarLayout) -> PlanPlacement? {
        let start = layout.minutes(forOffset: offset)
        let end = min(start + newBlockMinutes, layout.lastMinute)
        guard end - start >= CalendarLayout.snapMinutes else { return nil }
        return PlanPlacement(day: day, start: start, end: end)
    }

    /// A block whose top is dropped at `offset`: the same length, pulled back
    /// whole when it would run past 23:00; nil when it is longer than the
    /// visible hours.
    public static func move(
        _ block: CalendarItem, day: String, offset: CGFloat, layout: CalendarLayout
    ) -> PlanPlacement? {
        let length = block.end - block.start
        guard length <= layout.lastMinute - layout.firstMinute else { return nil }
        let start = min(layout.minutes(forOffset: offset), layout.lastMinute - length)
        return PlanPlacement(day: day, start: start, end: start + length)
    }

    /// A block whose bottom edge is dragged to `offset`: the end snaps, at
    /// least 15 minutes after the start and at most 23:00; nil when the
    /// minimum would reach midnight.
    public static func resize(_ block: CalendarItem, bottom offset: CGFloat, layout: CalendarLayout) -> PlanPlacement? {
        let end = max(layout.minutes(forOffset: offset), block.start + CalendarLayout.snapMinutes)
        guard end < midnight else { return nil }
        return PlanPlacement(day: block.day, start: block.start, end: end)
    }
}
