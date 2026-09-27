import Foundation
import OmakaseAPI
import SwiftData

/// Applies a range's fetched copy to the store. A block in `pending` keeps its
/// local state and is never deleted for being missing, and neither is a
/// `local-` placeholder the server has not seen yet.
@MainActor
struct RangeApply {
    let context: ModelContext
    let pending: Set<String>
    let window: RangeWindow

    func blocks(_ dtos: [TimeBlockDTO]) throws {
        for dto in dtos where !pending.contains(dto.id.uuidString) {
            let id = dto.id.uuidString
            let found = try context.fetch(FetchDescriptor<TimeBlockRecord>(predicate: #Predicate { $0.id == id }))
            if let existing = found.first { existing.apply(dto) } else { context.insert(TimeBlockRecord(dto: dto)) }
        }
        let keep = Set(dtos.map(\.id.uuidString)).union(pending)
        let days = window.days
        let inRange = try context.fetch(
            FetchDescriptor<TimeBlockRecord>(predicate: #Predicate { days.contains($0.day) }))
        for record in inRange where !keep.contains(record.id) && !record.id.hasPrefix("local-") {
            context.delete(record)
        }
    }

    func classes(_ dtos: [ClassOccurrenceDTO]) throws {
        for dto in dtos {
            let id = dto.id
            let found = try context.fetch(
                FetchDescriptor<ClassOccurrenceRecord>(predicate: #Predicate { $0.id == id }))
            if let existing = found.first {
                existing.apply(dto)
            } else {
                context.insert(ClassOccurrenceRecord(dto: dto))
            }
        }
        let keep = Set(dtos.map(\.id))
        let days = window.days
        let inRange = try context.fetch(
            FetchDescriptor<ClassOccurrenceRecord>(predicate: #Predicate { days.contains($0.day) }))
        for record in inRange where !keep.contains(record.id) { context.delete(record) }
    }

    func sessions(_ dtos: [PomodoroSessionDTO]) throws {
        for dto in dtos {
            let id = dto.id.uuidString
            let found = try context.fetch(FetchDescriptor<SessionRecord>(predicate: #Predicate { $0.id == id }))
            if let existing = found.first { existing.apply(dto) } else { context.insert(SessionRecord(dto: dto)) }
        }
        let keep = Set(dtos.map(\.id.uuidString))
        let (start, end) = (window.start, window.end)
        let inRange = try context.fetch(
            FetchDescriptor<SessionRecord>(predicate: #Predicate { $0.startedAt >= start && $0.startedAt < end }))
        for record in inRange where !keep.contains(record.id) { context.delete(record) }
    }

    /// The range's tasks, computed occurrences included (#206). Only a computed
    /// occurrence is removed for being missing: DaySync owns the rows, and a
    /// row outside today may simply not be scheduled in the range any more.
    func tasks(_ dtos: [TaskDTO]) throws {
        for dto in dtos where !pending.contains(dto.recordID) {
            let id = dto.recordID
            let found = try context.fetch(FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == id }))
            if let existing = found.first { existing.apply(dto) } else { context.insert(TaskRecord(dto: dto)) }
        }
        let keep = Set(dtos.map(\.recordID)).union(pending)
        let prefix = OccurrenceID.prefix
        let computed = try context.fetch(
            FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id.starts(with: prefix) }))
        let days = Set(window.days)
        for record in computed where !keep.contains(record.id) && days.contains(record.scheduledDay ?? "") {
            context.delete(record)
        }
    }
}
