import Foundation
import OmakaseAPI
import SwiftData

/// Refreshes the day: today's and carried-over tasks with their subtasks, the
/// day's blocks and study blocks, its review, and the profile. The server's
/// copy replaces the cache, except for items with queued writes, which keep
/// their local state until sent (M3.1 spec §2).
///
///     try await DaySync(context: container.mainContext, api: api).refresh()
@MainActor
public final class DaySync {
    private let context: ModelContext
    private let api: any APIClient
    private let clock: @Sendable () -> Date
    private let calendar: Calendar

    public init(
        context: ModelContext, api: any APIClient, clock: @escaping @Sendable () -> Date = { .now },
        calendar: Calendar = .current
    ) {
        (self.context, self.api, self.clock, self.calendar) = (context, api, clock, calendar)
    }

    /// "Today" is computed once per refresh, from the clock, so all six
    /// requests name the same day even across midnight (M3.1 Review Focus 4),
    /// and a window left open overnight moves to the new day (M1 Review Focus 2).
    public func refresh() async throws {
        let day = APIDay.today(calendar: calendar, now: clock())
        async let today = api.tasks(on: day)
        async let carried = api.carriedOver(on: day)
        async let blocks = api.timeBlocks(on: day)
        async let studies = api.studyBlocks(on: day)
        async let review = api.review(on: day)
        async let profile = api.profile()
        let apply = DayApply(context: context, pending: try pendingSubjects())
        try apply.tasks(try await today, carried: try await carried, on: day.string)
        try apply.blocks(try await blocks, on: day.string)
        try apply.studies(try await studies, on: day.string)
        try apply.review(try await review, on: day.string)
        try apply.profile(try await profile)
        try context.save()
    }

    private func pendingSubjects() throws -> Set<String> {
        Set(try context.fetch(FetchDescriptor<OutboxEntry>()).compactMap(\.subjectID))
    }
}
