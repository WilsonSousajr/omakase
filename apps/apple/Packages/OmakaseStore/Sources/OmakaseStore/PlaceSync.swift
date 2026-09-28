import Foundation
import OmakaseAPI
import SwiftData

/// A place id that isn't a UUID: never true for a project or discipline from
/// the library cache, which the server always sends as one.
public struct PlaceIDError: Error, Equatable, CustomStringConvertible {
    public let raw: String

    public var description: String { "id \(raw.debugDescription) is not a UUID" }
}

/// Refreshes one place's open tasks (spec §5): a project's, a discipline's,
/// or Life's. Follows `LibrarySync`'s pattern — read first, so a failed read
/// leaves the cache as it was — except the plain list also returns series
/// templates and skipped rows, which are dropped before the cache sees them.
///
///     try await PlaceSync(api: api, context: context).refresh(.discipline("d1"), today: "2026-09-27")
@MainActor
public final class PlaceSync {
    private let api: any APIClient
    private let context: ModelContext

    public init(api: any APIClient, context: ModelContext) { (self.api, self.context) = (api, context) }

    public func refresh(_ place: TaskPlace, today: String) async throws {
        // Snapshot before the read too: a write pending here and accepted
        // while the network call is in flight loses its outbox entry before
        // the after-snapshot can see it, but the read's DTO is still stale
        // relative to that acceptance (as DaySync and RangeSync guard,
        // final review, Important 1).
        let pendingBefore = try pendingSubjects()
        let dtos = try await api.openTasks(try query(for: place))
        let kept = dtos.filter { !isSeriesTemplate($0) && !$0.isSkipped }
        let pending = pendingBefore.union(try pendingSubjects())
        for dto in kept where !pending.contains(dto.recordID) { try upsert(dto) }
        try prune(place, keeping: Set(kept.map(\.recordID)), pending: pending, today: today)
        try context.save()
    }

    /// The server's template row for a series (#124): a rule with no series of its own.
    private func isSeriesTemplate(_ dto: TaskDTO) -> Bool { dto.recurrence != nil && dto.series == nil }

    private func query(for place: TaskPlace) throws -> PlaceTasksQuery {
        switch place {
        case .project(let id): return .project(try uuid(id))
        case .discipline(let id): return .discipline(try uuid(id))
        case .life: return .area(TaskArea.life.rawValue)
        }
    }

    private func uuid(_ raw: String) throws -> UUID {
        guard let id = UUID(uuidString: raw) else { throw PlaceIDError(raw: raw) }
        return id
    }

    private func upsert(_ dto: TaskDTO) throws {
        let id = dto.recordID
        let found = try context.fetch(FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == id }))
        if let existing = found.first { existing.apply(dto) } else { context.insert(TaskRecord(dto: dto)) }
    }

    /// Drops a cached open row this place's answer no longer has, except the
    /// rows DayApply also protects: pending, a placeholder id, or one
    /// DaySync owns — scheduled today or carried over (spec §5).
    private func prune(_ place: TaskPlace, keeping kept: Set<String>, pending: Set<String>, today: String) throws {
        let cached = try context.fetch(FetchDescriptor<TaskRecord>(predicate: place.openTasksPredicate))
        for record in cached where !kept.contains(record.id) && isPrunable(record, pending: pending, today: today) {
            context.delete(record)
        }
    }

    private func isPrunable(_ record: TaskRecord, pending: Set<String>, today: String) -> Bool {
        guard !pending.contains(record.id) else { return false }
        guard !record.id.hasPrefix("local-"), !record.id.hasPrefix(OccurrenceID.prefix) else { return false }
        return record.scheduledDay != today && !record.isCarriedOver
    }

    private func pendingSubjects() throws -> Set<String> {
        Set(try context.fetch(FetchDescriptor<OutboxEntry>()).compactMap(\.subjectID))
    }
}
