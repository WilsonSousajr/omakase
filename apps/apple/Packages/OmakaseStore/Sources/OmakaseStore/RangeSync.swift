import Foundation
import OmakaseAPI
import SwiftData

/// A day string that is not `YYYY-MM-DD`.
public struct RangeDayError: Error, Equatable, CustomStringConvertible {
    public let raw: String

    public var description: String { "day \(raw.debugDescription) is not YYYY-MM-DD" }
}

/// The days a refresh covers, and the instants that bound them in the user's
/// calendar: from the start of the first day to the start of the day after
/// the last. Sessions are ranged by these instants, not by UTC days.
struct RangeWindow {
    let first: APIDay
    let last: APIDay
    let days: [String]
    let start: Date
    let end: Date

    /// Nil for no days. `days` are contiguous, so the range is first...last.
    init?(days raw: [String], calendar: Calendar) throws {
        let parsed = try raw.map { text in
            guard let day = APIDay(string: text) else { throw RangeDayError(raw: text) }
            return day
        }
        guard let first = parsed.min(), let last = parsed.max() else { return nil }
        (self.first, self.last, days) = (first, last, parsed.map(\.string))
        start = Self.startOfDay(first, in: calendar)
        let lastStart = Self.startOfDay(last, in: calendar)
        end = calendar.date(byAdding: .day, value: 1, to: lastStart) ?? lastStart.addingTimeInterval(86_400)
    }

    /// From noon, because midnight does not exist on a DST day in some zones.
    private static func startOfDay(_ day: APIDay, in calendar: Calendar) -> Date {
        let noon = DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)
        return calendar.startOfDay(for: calendar.date(from: noon) ?? .distantPast)
    }
}

/// Refreshes the visible range for Plan: its blocks, class occurrences,
/// sessions (M4 spec §2 L), and its tasks with each series' occurrences (#206). The server's copy replaces the range's rows,
/// except blocks with queued writes and `local-` placeholders, as in DaySync.
///
///     try await RangeSync(api: api, context: container.mainContext).refresh(days: week)
@MainActor
public final class RangeSync {
    private let api: any APIClient
    private let context: ModelContext
    private let calendar: Calendar

    public init(api: any APIClient, context: ModelContext, calendar: Calendar = .current) {
        (self.api, self.context, self.calendar) = (api, context, calendar)
    }

    /// `days` are contiguous `YYYY-MM-DD` strings; none reads nothing.
    public func refresh(days: [String]) async throws {
        guard let window = try RangeWindow(days: days, calendar: calendar) else { return }
        async let blocks = api.timeBlocks(from: window.first, to: window.last)
        async let classes = api.classOccurrences(from: window.first, to: window.last)
        async let sessions = api.sessions(startedAfter: window.start, startedBefore: window.end)
        async let tasks = api.occurrences(from: window.first, to: window.last)
        let queuedBefore = try pendingSubjects()
        let fetched = try await (blocks, classes, sessions, tasks)
        // Read again after the network: a write made meanwhile keeps its block (as DaySync does).
        let apply = RangeApply(context: context, pending: queuedBefore.union(try pendingSubjects()), window: window)
        try apply.blocks(fetched.0)
        try apply.classes(fetched.1)
        try apply.sessions(fetched.2)
        try apply.tasks(fetched.3)
        try context.save()
    }

    private func pendingSubjects() throws -> Set<String> {
        Set(try context.fetch(FetchDescriptor<OutboxEntry>()).compactMap(\.subjectID))
    }
}
