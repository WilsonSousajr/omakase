import Foundation
import OmakaseAPI
import SwiftData

/// Study's writes (#227), online through `DirectWrites` (parent spec
/// L136-139): a form POSTed when new, PATCHed onto `existing` otherwise. A
/// delete also takes from the cache what the server cascades.
///
///     let semester = try await StudyWrites(api: api, context: context).save(form, existing: nil)
@MainActor
public struct StudyWrites {
    private let writes: DirectWrites
    private let context: ModelContext

    public init(api: any APIClient, context: ModelContext) {
        (writes, self.context) = (DirectWrites(api: api, context: context), context)
    }

    @discardableResult
    public func save(_ form: SemesterForm, existing: SemesterRecord?) async throws -> SemesterRecord {
        try await save(form, "semesters", existing)
    }

    @discardableResult
    public func save(_ form: DisciplineForm, existing: DisciplineRecord?) async throws -> DisciplineRecord {
        try await save(form, "disciplines", existing)
    }

    @discardableResult
    public func save(_ form: ClassScheduleForm, existing: ClassScheduleRecord?) async throws -> ClassScheduleRecord {
        try await save(form, "classschedules", existing)
    }

    @discardableResult
    public func save(_ form: HolidayForm, existing: HolidayRecord?) async throws -> HolidayRecord {
        try await save(form, "holidays", existing)
    }

    /// Its disciplines (with their schedules) and its holidays go too.
    public func delete(_ semester: SemesterRecord) async throws {
        let id = semester.id
        try await writes.delete(semester, path: Self.path("semesters", id))
        let disciplines = try context.fetch(
            FetchDescriptor<DisciplineRecord>(predicate: #Predicate { $0.semesterID == id }))
        for discipline in disciplines { try dropSchedules(of: discipline.id) }
        for discipline in disciplines { context.delete(discipline) }
        try context.delete(model: HolidayRecord.self, where: #Predicate { $0.semesterID == id })
        try context.save()
    }

    /// Its class schedules go too.
    public func delete(_ discipline: DisciplineRecord) async throws {
        let id = discipline.id
        try await writes.delete(discipline, path: Self.path("disciplines", id))
        try dropSchedules(of: id)
        try context.save()
    }

    public func delete(_ schedule: ClassScheduleRecord) async throws {
        try await writes.delete(schedule, path: Self.path("classschedules", schedule.id))
    }

    public func delete(_ holiday: HolidayRecord) async throws {
        try await writes.delete(holiday, path: Self.path("holidays", holiday.id))
    }

    private func save<Record: LibraryCached>(
        _ form: some Encodable, _ collection: String, _ existing: Record?
    ) async throws -> Record {
        let body = try JSONEncoder().encode(form)
        guard let existing else {
            return try await writes.save(Record.self, "POST", "/api/v1/study/\(collection)/", body: body)
        }
        return try await writes.save(Record.self, "PATCH", Self.path(collection, existing.id), body: body)
    }

    private func dropSchedules(of disciplineID: String) throws {
        try context.delete(model: ClassScheduleRecord.self, where: #Predicate { $0.disciplineID == disciplineID })
    }

    private static func path(_ collection: String, _ id: String) -> String {
        "/api/v1/study/\(collection)/\(id.lowercased())/"
    }
}
