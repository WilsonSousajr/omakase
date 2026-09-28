import OmakaseStore

/// One thing on the Plan grid, as a value: a planned block, a class, or a
/// focus session that actually ran (spec M4, Grid). The grid never reads
/// store records, so the class and session records (#200) plug in by
/// mapping to this.
///
///     CalendarItem(id: "b1", day: "2026-09-26", start: 540, end: 600, title: "Essay", kind: .block)
public struct CalendarItem: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Planned: a bar on solid surface (#283), laned beside overlapping blocks.
        case block
        /// Fixed by the timetable: dashed, drawn behind the blocks.
        case classOccurrence
        /// What ran (R8): a thin lane at the column's trailing edge.
        case focusSession
        /// Read from Calendar.app (#229): dashed and muted behind the
        /// blocks, never laned with them and never draggable.
        case externalEvent
    }

    public let id: String
    /// "YYYY-MM-DD", the client's day.
    public let day: String
    /// Minutes since midnight.
    public let start: Int
    public let end: Int
    public let title: String
    public let kind: Kind
    /// The source's colour when one is cached (a project's, a
    /// discipline's, or the kind's own token), else nil (spec §9).
    public let tint: DesignColor?
    /// A block's parent task, which its panel opens (#217); nil for a study
    /// block's, a class and a session.
    public let taskID: String?
    /// A class cancelled on this date (#207): still drawn, struck through.
    public let isCancelled: Bool
    /// The kind's SF Symbol beside the title (spec §9): a class keeps
    /// `book`; a block's own kind glyph when its parent is cached; nil
    /// otherwise, and for a session or an external event.
    public let symbol: String?

    public init(
        id: String, day: String, start: Int, end: Int, title: String, kind: Kind, tint: DesignColor? = nil,
        taskID: String? = nil, isCancelled: Bool = false, symbol: String? = nil
    ) {
        (self.id, self.day, self.start, self.end) = (id, day, start, end)
        (self.title, self.kind, self.tint) = (title, kind, tint)
        (self.taskID, self.isCancelled, self.symbol) = (taskID, isCancelled, symbol)
    }

    /// A block is tall enough for a second line under its title (spec §9):
    /// at `CalendarLayout.standard`'s scale that is a block of at least
    /// `timeRangeMinMinutes`, which reads about 40 pt tall - room for the
    /// title and the time below it. Classes keep only their title.
    public static let timeRangeMinMinutes = 45

    /// Whether this item shows its time range under the title (spec §9).
    public var showsTimeRange: Bool { kind == .block && end - start >= Self.timeRangeMinMinutes }

    /// A class's context-menu item: whichever of cancel and restore applies.
    public var cancellationMenuTitle: String { isCancelled ? "Restore class" : "Cancel this class" }

    /// Without a source colour an item is accent grey (spec M4, Grid).
    public var color: DesignColor { tint ?? Palette.accent }

    /// "09:00 – 10:30", as the block panel shows it (#217).
    public var timeRange: String { "\(Self.clock(start)) – \(Self.clock(end))" }

    static func clock(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }

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
        id: String, day: String, startTime: String, endTime: String, title: String, taskID: String? = nil,
        tint: DesignColor? = nil, symbol: String? = nil
    ) -> CalendarItem? {
        guard let start = minutes(fromClock: startTime), let end = minutes(fromClock: endTime), end > start else {
            return nil
        }
        return CalendarItem(
            id: id, day: day, start: start, end: end, title: title, kind: .block, tint: tint, taskID: taskID,
            symbol: symbol)
    }

    /// A block shows its parent's title; a parent the store doesn't hold
    /// (M5 caches more study blocks) leaves the generic name.
    public static func blockTitle(taskID: String?, studyBlockID: String?, titles: [String: String]) -> String {
        taskID.flatMap { titles[$0] } ?? studyBlockID.flatMap { titles[$0] } ?? "Time block"
    }

    /// The grid's block for a cached record (spec §9): `titles` maps a
    /// parent's id to its title, `marks` to its colour and `symbols` to its
    /// kind glyph, all keyed by the block's task id, else its study block's.
    @MainActor
    public static func block(
        _ record: TimeBlockRecord, titles: [String: String], marks: [String: DesignColor] = [:],
        symbols: [String: String] = [:]
    ) -> CalendarItem? {
        let title = blockTitle(taskID: record.taskID, studyBlockID: record.studyBlockID, titles: titles)
        let parentID = record.taskID ?? record.studyBlockID
        return block(
            id: record.id, day: record.day, startTime: record.startTime, endTime: record.endTime, title: title,
            taskID: record.taskID, tint: parentID.flatMap { marks[$0] }, symbol: parentID.flatMap { symbols[$0] })
    }

    /// Every visible block's tint (spec §9): a task's through its own
    /// filing, a study block's through its discipline - both
    /// `directory.mark(for:).color` - keyed by whichever id the block will
    /// look itself up by.
    @MainActor
    public static func marks(
        tasks: [TaskRecord], studies: [StudyBlockRecord], directory: PlaceDirectory
    ) -> [String: DesignColor] {
        var marks = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, directory.mark(for: $0.filing).color) })
        for study in studies {
            let filing = TaskFiling(area: .study, parent: .discipline(study.disciplineID))
            marks[study.id] = directory.mark(for: filing).color
        }
        return marks
    }

    /// Every visible block's kind glyph (spec §9): a task's own kind, a
    /// study block's always Study's - that is what a study block is.
    @MainActor
    public static func symbols(tasks: [TaskRecord], studies: [StudyBlockRecord]) -> [String: String] {
        var symbols = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.filing.area.symbol) })
        for study in studies { symbols[study.id] = TaskArea.study.symbol }
        return symbols
    }
}
