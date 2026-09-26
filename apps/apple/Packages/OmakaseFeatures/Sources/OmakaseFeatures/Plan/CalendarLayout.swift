import CoreGraphics

/// A block's place among the blocks it overlaps: lane `index` of `count`.
public struct CalendarLane: Equatable, Sendable {
    public let index: Int
    public let count: Int

    public init(index: Int, count: Int) { (self.index, self.count) = (index, count) }
}

/// Where an item sits down a day column.
public struct CalendarBand: Equatable, Sendable {
    public let y: CGFloat
    public let height: CGFloat

    public init(y: CGFloat, height: CGFloat) { (self.y, self.height) = (y, height) }
}

/// Where an item sits across a day column.
public struct CalendarSpan: Equatable, Sendable {
    public let x: CGFloat
    public let width: CGFloat

    public init(x: CGFloat, width: CGFloat) { (self.x, self.width) = (x, width) }
}

/// The Plan grid's geometry, pure so it is tested without a view (spec M4,
/// Grid): hours 06:00-23:00 at 52 pt, times snapped to 15 minutes, items
/// clipped to the visible hours, overlapping blocks side by side in lanes.
///
///     let band = CalendarLayout.standard.band(for: item)   // nil when outside the hours
public struct CalendarLayout: Equatable, Sendable {
    public static let standard = CalendarLayout()
    public static let snapMinutes = 15
    /// A five-minute block still shows its title's first line.
    public static let minimumHeight: CGFloat = 18
    public static let sessionLaneWidth: CGFloat = 6
    public static let laneGap: CGFloat = 2

    public let firstHour: Int
    public let lastHour: Int
    public let hourHeight: CGFloat

    public init(firstHour: Int = 6, lastHour: Int = 23, hourHeight: CGFloat = 52) {
        (self.firstHour, self.lastHour, self.hourHeight) = (firstHour, lastHour, hourHeight)
    }

    /// The hours that get a row and a label.
    public var hours: [Int] { Array(firstHour..<lastHour) }
    public var totalHeight: CGFloat { CGFloat(lastHour - firstHour) * hourHeight }
    private var firstMinute: Int { firstHour * 60 }
    private var lastMinute: Int { lastHour * 60 }

    public func y(forMinutes minutes: Int) -> CGFloat {
        CGFloat(minutes - firstMinute) / 60 * hourHeight
    }

    /// The quarter hour nearest `y`, kept inside the visible hours.
    public func minutes(forY y: CGFloat) -> Int {
        let quarters = (y / hourHeight * 60 / CGFloat(Self.snapMinutes)).rounded()
        let snapped = firstMinute + Int(quarters) * Self.snapMinutes
        return min(max(snapped, firstMinute), lastMinute)
    }

    /// The item's visible part down the column, at least `minimumHeight`
    /// tall; nil when none of it falls within the hours.
    public func band(for item: CalendarItem) -> CalendarBand? {
        let (start, end) = (max(item.start, firstMinute), min(item.end, lastMinute))
        guard end > start else { return nil }
        let top = y(forMinutes: start)
        return CalendarBand(y: top, height: max(y(forMinutes: end) - top, Self.minimumHeight))
    }

    /// Lanes for the blocks, per day: each overlapping cluster is packed
    /// greedily, and every block in it learns the cluster's lane count.
    /// Classes are drawn behind and sessions beside, so neither is laned.
    public static func lanes(for items: [CalendarItem]) -> [String: CalendarLane] {
        let blocks = items.filter { $0.kind == .block }.sorted { ($0.day, $0.start, $0.end) < ($1.day, $1.start, $1.end) }
        var lanes: [String: CalendarLane] = [:]
        for cluster in clusters(of: blocks) {
            lanes.merge(packed(cluster)) { first, _ in first }
        }
        return lanes
    }

    /// The block's share of the column, leaving the session lane free.
    public static func blockSpan(lane: CalendarLane?, width: CGFloat) -> CalendarSpan {
        let lane = lane ?? CalendarLane(index: 0, count: 1)
        let laneWidth = (width - sessionLaneWidth - laneGap) / CGFloat(max(lane.count, 1))
        return CalendarSpan(x: CGFloat(lane.index) * laneWidth, width: max(laneWidth - laneGap, 0))
    }

    public static func sessionSpan(width: CGFloat) -> CalendarSpan {
        CalendarSpan(x: width - sessionLaneWidth, width: sessionLaneWidth)
    }

    /// Runs of blocks, sorted by day and start, where each overlaps the run
    /// so far. Touching (one's end is the next's start) is not overlapping.
    private static func clusters(of sorted: [CalendarItem]) -> [[CalendarItem]] {
        var clusters: [[CalendarItem]] = []
        var reach = (day: "", end: Int.min)
        for block in sorted {
            if block.day == reach.day, block.start < reach.end, !clusters.isEmpty {
                clusters[clusters.count - 1].append(block)
            } else {
                clusters.append([block])
            }
            reach = (block.day, block.day == reach.day ? max(reach.end, block.end) : block.end)
        }
        return clusters
    }

    /// Each block takes the first lane whose last block has ended.
    private static func packed(_ cluster: [CalendarItem]) -> [String: CalendarLane] {
        var laneEnds: [Int] = []
        var indexes: [(id: String, lane: Int)] = []
        for block in cluster {
            let free = laneEnds.firstIndex { $0 <= block.start } ?? laneEnds.count
            if free == laneEnds.count { laneEnds.append(block.end) } else { laneEnds[free] = block.end }
            indexes.append((block.id, free))
        }
        let count = laneEnds.count
        return Dictionary(indexes.map { ($0.id, CalendarLane(index: $0.lane, count: count)) }) { first, _ in first }
    }
}
