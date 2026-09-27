import Foundation
import OmakaseFeatures
import OmakaseStore
import SwiftData

extension AppServices {
    /// Study's writes (#227): online, through StudyWrites; the record an edit
    /// or a delete names is looked up in the cache, and one gone is a no-op.
    func studyActions() -> StudyModel.Actions {
        let writes = StudyWrites(api: api, context: container.mainContext)
        return StudyModel.Actions(
            saveSemester: { [self] form, id in try await writes.save(form, existing: record(SemesterRecord.self, id)) },
            saveDiscipline: { [self] form, id in
                try await writes.save(form, existing: record(DisciplineRecord.self, id))
            },
            saveSchedule: { [self] form, id in
                try await writes.save(form, existing: record(ClassScheduleRecord.self, id))
            },
            saveHoliday: { [self] form, id in try await writes.save(form, existing: record(HolidayRecord.self, id)) },
            delete: { [self] deletion in try await delete(deletion, with: writes) })
    }

    private func delete(_ deletion: StudyModel.Deletion, with writes: StudyWrites) async throws {
        switch deletion {
        case .semester(let id): if let semester = record(SemesterRecord.self, id) { try await writes.delete(semester) }
        case .discipline(let id):
            if let discipline = record(DisciplineRecord.self, id) { try await writes.delete(discipline) }
        case .schedule(let id):
            if let schedule = record(ClassScheduleRecord.self, id) { try await writes.delete(schedule) }
        case .holiday(let id): if let holiday = record(HolidayRecord.self, id) { try await writes.delete(holiday) }
        }
    }

    private func record<Record: LibraryCached>(_ type: Record.Type, _ id: String?) -> Record? {
        guard let id else { return nil }
        return try? container.mainContext.fetch(FetchDescriptor<Record>()).first { $0.id == id }
    }
}
