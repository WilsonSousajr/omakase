import Foundation
import OmakaseAPI
import SwiftData

/// Refreshes the library (#224): workspaces, projects, and every semester's
/// disciplines, class schedules and holidays, plus the Inbox's unscheduled
/// tasks. The lists are small, so each is read whole and replaced. Library
/// writes are online-only (M5 spec), so nothing there is ever pending; only
/// an Inbox task with a queued write keeps its local copy.
///
///     try await LibrarySync(api: api, context: context).refresh()
@MainActor
public final class LibrarySync {
    private let api: any APIClient
    private let context: ModelContext

    public init(api: any APIClient, context: ModelContext) { (self.api, self.context) = (api, context) }

    /// Reads everything first, so a failed read leaves the cache as it was.
    public func refresh() async throws {
        async let workspaces = api.workspaces()
        async let projects = api.projects()
        async let semesters = api.semesters()
        async let disciplines = api.disciplines()
        async let schedules = api.classSchedules()
        async let holidays = api.holidays()
        async let inbox = api.unscheduledTasks()
        let lists = try await (workspaces, projects, semesters, disciplines, schedules, holidays, inbox)
        try replace(WorkspaceRecord.self, with: lists.0)
        try replace(ProjectRecord.self, with: lists.1)
        try replace(SemesterRecord.self, with: lists.2)
        try replace(DisciplineRecord.self, with: lists.3)
        try replace(ClassScheduleRecord.self, with: lists.4)
        try replace(HolidayRecord.self, with: lists.5)
        try applyInbox(lists.6)
        try context.save()
    }

    private func replace<Record: LibraryCached>(_ type: Record.Type, with dtos: [Record.DTO]) throws {
        let cached = Dictionary(
            try context.fetch(FetchDescriptor<Record>()).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for dto in dtos {
            if let record = cached[dto.id.uuidString] { record.apply(dto) } else { context.insert(Record(dto: dto)) }
        }
        let kept = Set(dtos.map(\.id.uuidString))
        for (id, record) in cached where !kept.contains(id) { context.delete(record) }
    }

    /// The Inbox's tasks are the ones with no day; a scheduled task belongs to
    /// DaySync, and a task with a queued write or a local id keeps its copy.
    private func applyInbox(_ dtos: [TaskDTO]) throws {
        let pending = Set(try context.fetch(FetchDescriptor<OutboxEntry>()).compactMap(\.subjectID))
        let unscheduled = try context.fetch(
            FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.scheduledDay == nil }))
        let cached = Dictionary(unscheduled.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for dto in dtos where !pending.contains(dto.id.uuidString) {
            if let record = cached[dto.id.uuidString] {
                record.apply(dto)
            } else {
                context.insert(TaskRecord(dto: dto))
            }
        }
        let kept = Set(dtos.map(\.id.uuidString)).union(pending)
        for (id, record) in cached where !kept.contains(id) && !id.hasPrefix("local-") { context.delete(record) }
    }
}
