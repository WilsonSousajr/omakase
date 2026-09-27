import OmakaseStore

/// One thing on the Plan grid, as a value: a planned block, a class, or a
/// focus session that actually ran (spec M4, Grid). The grid never reads
/// store records, so the class and session records (#200) plug in by
/// mapping to this.
///
///     CalendarItem(id: "b1", day: "2026-09-26", start: 540, end: 600, title: "Essay", kind: .block)
public struct CalendarItem: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Planned: a bar and a faint fill, laned beside overlapping blocks.
        case block
        /// Fixed by the timetable: dashed, drawn behind the blocks.
        case classOccurrence
        /// What ran (R8): a thin lane at the column's trailing edge.
        case focusSession
    }

    public let id: String
    /// "YYYY-MM-DD", the client's day.
    public let day: String
    /// Minutes since midnight.
    public let start: Int
    public let end: Int
    public let title: String
    public let kind: Kind
    /// The source's colour when one is cached (a discipline's), else nil.
    public let tint: DesignColor?

    public init(
        id: String, day: String, start: Int, end: Int, title: String, kind: Kind, tint: DesignColor? = nil
    ) {
        (self.id, self.day, self.start, self.end) = (id, day, start, end)
        (self.title, self.kind, self.tint) = (title, kind, tint)
    }

    /// Without a source colour an item is accent grey (spec M4, Grid).
    public var color: DesignColor { tint ?? Palette.accent }

    /// "HH:MM:SS" or "HH:MM", as the server sends block times, in minutes
    /// since midnight; nil for anything else.
    public static func minutes(fromClock text: String) -> Int? {
        guard let match = text.wholeMatch(of: /(\d{2}):(\d{2})(?::\d{2})?/),
            let hour = Int(match.1), let minute = Int(match.2), hour < 24, minute < 60
        else { return nil }
        return hour * 60 + minute
    }

    /// A block from its record's fields; nil when its times don't parse or
    /// don't run forwards, which the server's constraint already forbids.
    public static func block(
        id: String, day: String, startTime: String, endTime: String, title: String
    ) -> CalendarItem? {
        guard let start = minutes(fromClock: startTime), let end = minutes(fromClock: endTime), end > start else {
            return nil
        }
        return CalendarItem(id: id, day: day, start: start, end: end, title: title, kind: .block)
    }

    /// A block shows its parent's title; a parent the store doesn't hold
    /// (M5 caches more study blocks) leaves the generic name.
    public static func blockTitle(taskID: String?, studyBlockID: String?, titles: [String: String]) -> String {
        taskID.flatMap { titles[$0] } ?? studyBlockID.flatMap { titles[$0] } ?? "Time block"
    }

    /// The grid's block for a cached record; `titles` maps a parent's id to its title.
    @MainActor
    public static func block(_ record: TimeBlockRecord, titles: [String: String]) -> CalendarItem? {
        let title = blockTitle(taskID: record.taskID, studyBlockID: record.studyBlockID, titles: titles)
        return block(
            id: record.id, day: record.day, startTime: record.startTime, endTime: record.endTime, title: title)
    }
}
