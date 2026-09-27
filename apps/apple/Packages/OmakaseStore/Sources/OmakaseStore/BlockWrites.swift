import Foundation
import OmakaseAPI
import SwiftData

/// A block's writes: placed, moved and deleted in Plan (#201), and its session
/// notes and rating after a pomodoro (M3.3). Each updates the local model and
/// queues its outbox entry in one save. A task's scheduled day follows its
/// block (M4 spec, Decisions); a study block's is not cached until M5.
///
///     let block = try BlockWrites(context: ctx).create(
///         taskID: task.id, studyBlockID: nil, day: "2026-03-07", start: "09:00:00", end: "10:00:00")
@MainActor
public final class BlockWrites {
    public enum Failure: Error, Equatable, CustomStringConvertible {
        case parentCount(taskID: String?, studyBlockID: String?)

        public var description: String {
            switch self {
            case .parentCount(let taskID, let studyBlockID):
                "a block needs exactly one parent, a task or a study block; got task \(taskID ?? "nil") "
                    + "and study block \(studyBlockID ?? "nil")"
            }
        }
    }

    private let context: ModelContext
    private let queue: OutboxQueue

    public init(context: ModelContext) { (self.context, queue) = (context, OutboxQueue(context: context)) }

    /// A block shown at once under a `local-` id; `start` and `end` are "HH:MM:SS".
    public func create(
        taskID: String?, studyBlockID: String?, day: String, start: String, end: String
    ) throws -> TimeBlockRecord {
        guard (taskID == nil) != (studyBlockID == nil) else {
            throw Failure.parentCount(taskID: taskID, studyBlockID: studyBlockID)
        }
        let block = TimeBlockRecord(
            id: "local-\(UUID().uuidString)", day: day, startTime: start, endTime: end, taskID: taskID,
            studyBlockID: studyBlockID)
        context.insert(block)
        let body = CreateBody(task: taskID, studyBlock: studyBlockID, date: day, startTime: start, endTime: end)
        try queue.enqueue(
            kind: "block.create", method: "POST", path: "/api/v1/timeblocks/",
            body: try OmakaseJSON.encoder.encode(body), subjectID: block.id, createsLocalID: block.id)
        try saveFollowingParent(of: block)
        return block
    }

    public func move(_ block: TimeBlockRecord, day: String, start: String, end: String) throws {
        let dayChanged = block.day != day
        (block.day, block.startTime, block.endTime) = (day, start, end)
        try enqueuePatch(
            block, body: try OmakaseJSON.encoder.encode(MoveBody(date: day, startTime: start, endTime: end)))
        guard dayChanged else { return try context.save() }
        try saveFollowingParent(of: block)
    }

    /// A block whose create never reached the server takes that create, and
    /// the writes queued on it, with it rather than queueing a delete.
    public func delete(_ block: TimeBlockRecord) throws {
        let id = block.id
        context.delete(block)
        if let create = queue.unsentCreate(of: id) {
            queue.withdraw(create)
        } else {
            try queue.enqueue(
                kind: "block.delete", method: "DELETE", path: "/api/v1/timeblocks/\(id)/", body: nil, subjectID: id)
        }
        try context.save()
    }

    public func saveNotes(_ block: TimeBlockRecord, _ notes: String) throws {
        block.notes = notes
        try patch(block, body: try OmakaseJSON.encoder.encode(["notes": notes]))
    }

    public func rate(_ block: TimeBlockRecord, _ rating: Int) throws {
        block.sessionRating = rating
        try patch(block, body: try OmakaseJSON.encoder.encode(["session_rating": rating]))
    }

    private func patch(_ block: TimeBlockRecord, body: Data) throws {
        try enqueuePatch(block, body: body)
        try context.save()
    }

    private func enqueuePatch(_ block: TimeBlockRecord, body: Data) throws {
        try queue.enqueue(
            kind: "block.patch", method: "PATCH", path: "/api/v1/timeblocks/\(block.id)/", body: body,
            subjectID: block.id)
    }

    /// Saves, rescheduling the parent task first when it is on another day;
    /// the task's patch shares the save.
    private func saveFollowingParent(of block: TimeBlockRecord) throws {
        guard let task = parentTask(of: block), task.scheduledDay != block.day else { return try context.save() }
        try TaskWrites(context: context).reschedule(task, to: block.day)
    }

    private func parentTask(of block: TimeBlockRecord) -> TaskRecord? {
        guard let taskID = block.taskID else { return nil }
        return try? context.fetch(FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == taskID })).first
    }

    /// Exactly one parent is set; the nil one is omitted.
    private struct CreateBody: Encodable {
        let task: String?
        let studyBlock: String?
        let date: String
        let startTime: String
        let endTime: String
    }

    private struct MoveBody: Encodable {
        let date: String
        let startTime: String
        let endTime: String
    }
}

/// A block write was accepted: the server's copy replaces the local one unless
/// a later write is queued, and a create's `local-` block takes the server's
/// id and its parent's. A delete's reply (204, or 404 when already gone) has
/// no block, so it changes nothing.
@MainActor
public final class BlockHandler: OutboxHandler {
    public let kinds = ["block.patch", "block.create", "block.delete"]
    private let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    public func apply(_ entry: OutboxEntry, body: Data) {
        guard let dto = try? OmakaseJSON.decoder.decode(TimeBlockDTO.self, from: body) else { return }
        let serverID = dto.id.uuidString
        let localID = entry.createsLocalID ?? serverID
        let descriptor = FetchDescriptor<TimeBlockRecord>(
            predicate: #Predicate { $0.id == localID || $0.id == serverID })
        guard let record = try? context.fetch(descriptor).first else { return }
        // The parent may have been `local-` too; its id is the server's now,
        // whatever later write keeps the rest of the local state (#201).
        (record.id, record.taskID, record.studyBlockID) = (serverID, dto.task?.uuidString, dto.studyBlock?.uuidString)
        guard !OutboxQueue(context: context).hasLaterPendingWrite(than: entry, for: [localID, serverID]) else {
            return
        }
        record.apply(dto)
    }
}
