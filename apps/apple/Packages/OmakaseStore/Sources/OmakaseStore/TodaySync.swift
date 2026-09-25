import Foundation
import OmakaseAPI
import SwiftData

/// Refreshes today's window: the server's copy replaces the cache, except for
/// items with queued writes, which keep their local state until sent.
///
///     try await TodaySync(context: container.mainContext, api: api).refresh()
@MainActor
public final class TodaySync {
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

    /// "Today" is recomputed from the clock on every call (Review Focus 2).
    public func refresh() async throws {
        let day = APIDay.today(calendar: calendar, now: clock())
        let fresh = try await api.tasks(on: day)
        let pending = try pendingSubjects()
        try upsert(fresh.filter { !pending.contains($0.id.uuidString) })
        try removeMissing(on: day, keeping: Set(fresh.map(\.id.uuidString)).union(pending))
        try context.save()
    }

    private func pendingSubjects() throws -> Set<String> {
        Set(try context.fetch(FetchDescriptor<OutboxEntry>()).compactMap(\.subjectID))
    }

    private func upsert(_ tasks: [TaskDTO]) throws {
        for task in tasks {
            let id = task.id.uuidString
            let existing = try context.fetch(FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == id })).first
            if let existing { existing.apply(task) } else { context.insert(TaskRecord(dto: task)) }
        }
    }

    private func removeMissing(on day: APIDay, keeping ids: Set<String>) throws {
        let dayString: String? = day.string
        let descriptor = FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.scheduledDay == dayString })
        for record in try context.fetch(descriptor) where !ids.contains(record.id) && !record.id.hasPrefix("local-") {
            context.delete(record)
        }
    }
}
