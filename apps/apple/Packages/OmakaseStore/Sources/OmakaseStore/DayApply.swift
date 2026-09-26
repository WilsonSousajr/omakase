import Foundation
import OmakaseAPI
import SwiftData

/// Applies one day's fetched copy to the store. `pending` holds the subjects
/// of queued writes: those items keep their local state until sent, and are
/// never deleted for being missing from the server's answer.
@MainActor
struct DayApply {
    let context: ModelContext
    let pending: Set<String>

    func tasks(_ today: [TaskDTO], carried: [TaskDTO], on day: String) throws {
        for dto in today { try upsertTask(dto, carried: false) }
        for dto in carried { try upsertTask(dto, carried: true) }
        let keep = Set((today + carried).map(\.id.uuidString)).union(pending)
        let onDay: String? = day
        let descriptor = FetchDescriptor<TaskRecord>(
            predicate: #Predicate { $0.scheduledDay == onDay || $0.isCarriedOver })
        for record in try context.fetch(descriptor) where !keep.contains(record.id) && !record.id.hasPrefix("local-") {
            try deleteSubtasks(of: record.id)
            context.delete(record)
        }
    }

    func blocks(_ dtos: [TimeBlockDTO], on day: String) throws {
        for dto in dtos where !pending.contains(dto.id.uuidString) {
            let id = dto.id.uuidString
            let found = try context.fetch(FetchDescriptor<TimeBlockRecord>(predicate: #Predicate { $0.id == id }))
            if let existing = found.first { existing.apply(dto) } else { context.insert(TimeBlockRecord(dto: dto)) }
        }
        let keep = Set(dtos.map(\.id.uuidString)).union(pending)
        let onDay = try context.fetch(FetchDescriptor<TimeBlockRecord>(predicate: #Predicate { $0.day == day }))
        for record in onDay where !keep.contains(record.id) { context.delete(record) }
    }

    func studies(_ dtos: [StudyBlockDTO], on day: String) throws {
        for dto in dtos where !pending.contains(dto.id.uuidString) {
            let id = dto.id.uuidString
            let found = try context.fetch(FetchDescriptor<StudyBlockRecord>(predicate: #Predicate { $0.id == id }))
            if let existing = found.first { existing.apply(dto) } else { context.insert(StudyBlockRecord(dto: dto)) }
        }
        let keep = Set(dtos.map(\.id.uuidString)).union(pending)
        let scheduled: String? = day
        let onDay = try context.fetch(
            FetchDescriptor<StudyBlockRecord>(predicate: #Predicate { $0.scheduledDay == scheduled }))
        for record in onDay where !keep.contains(record.id) { context.delete(record) }
    }

    func review(_ dto: DailyReviewDTO?, on day: String) throws {
        guard !pending.contains(DailyReviewRecord.subjectID(for: day)) else { return }
        let found = try context.fetch(FetchDescriptor<DailyReviewRecord>(predicate: #Predicate { $0.day == day }))
        switch (dto, found.first) {
        case (let dto?, let record?): record.apply(dto)
        case (let dto?, nil):
            let record = DailyReviewRecord(day: day)
            record.apply(dto)
            context.insert(record)
        case (nil, let record?): context.delete(record)
        case (nil, nil): break
        }
    }

    func profile(_ dto: ProfileDTO) throws {
        if let record = try context.fetch(FetchDescriptor<ProfileRecord>()).first {
            record.apply(dto)
        } else {
            context.insert(ProfileRecord(dto: dto))
        }
    }

    private func upsertTask(_ dto: TaskDTO, carried: Bool) throws {
        let id = dto.id.uuidString
        guard !pending.contains(id) else { return }
        let record: TaskRecord
        if let existing = try fetchTask(id) {
            record = existing
        } else {
            record = TaskRecord(dto: dto)
            context.insert(record)
        }
        record.apply(dto)
        record.isCarriedOver = carried
        if let subtasks = dto.subtasks { try replaceSubtasks(of: id, with: subtasks) }
    }

    private func replaceSubtasks(of taskID: String, with dtos: [SubtaskDTO]) throws {
        let fresh = Set(dtos.map(\.id.uuidString))
        for record in try subtasks(of: taskID) where !fresh.contains(record.id) && !pending.contains(record.id) {
            context.delete(record)
        }
        for dto in dtos where !pending.contains(dto.id.uuidString) {
            let id = dto.id.uuidString
            let found = try context.fetch(FetchDescriptor<SubtaskRecord>(predicate: #Predicate { $0.id == id }))
            if let existing = found.first {
                existing.apply(dto)
            } else {
                context.insert(SubtaskRecord(dto: dto, taskID: taskID))
            }
        }
    }

    private func fetchTask(_ id: String) throws -> TaskRecord? {
        try context.fetch(FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == id })).first
    }

    private func subtasks(of taskID: String) throws -> [SubtaskRecord] {
        try context.fetch(FetchDescriptor<SubtaskRecord>(predicate: #Predicate { $0.taskID == taskID }))
    }

    private func deleteSubtasks(of taskID: String) throws {
        for record in try subtasks(of: taskID) { context.delete(record) }
    }
}
