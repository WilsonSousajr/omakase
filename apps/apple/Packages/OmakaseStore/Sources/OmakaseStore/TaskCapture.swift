import Foundation
import SwiftData

/// What the capture panel adds to a task beyond its title and filing
/// (glass-pass §4, #286): each field nil (or no subtasks) when not set, so
/// the create leaves it to the server's default.
///
///     TaskCaptureDetails(priority: "high", estimatedMinutes: 45, subtasks: ["Outline", "Draft"])
public struct TaskCaptureDetails: Equatable, Sendable {
    public var priority: String?
    public var estimatedMinutes: Int?
    /// The server's `description`, as the task editor calls it.
    public var notes: String?
    /// Titles, in order; each becomes a subtask behind the task.
    public var subtasks: [String]

    public init(
        priority: String? = nil, estimatedMinutes: Int? = nil, notes: String? = nil, subtasks: [String] = []
    ) {
        (self.priority, self.estimatedMinutes) = (priority, estimatedMinutes)
        (self.notes, self.subtasks) = (notes, subtasks)
    }
}

/// A slot drawn on Plan (S11, #264): the block a capture adds on `day`,
/// with `start` and `end` as "HH:MM:SS".
public struct CaptureSlot: Equatable, Sendable {
    public let day: String
    public let start: String
    public let end: String

    public init(day: String, start: String, end: String) { (self.day, self.start, self.end) = (day, start, end) }
}

/// A capture that saved its task but not everything with it (S11's review,
/// #286): the task stays, with its create queued, so the caller reports what
/// is missing rather than calling the capture done.
public enum TaskCaptureError: Error, Equatable, CustomStringConvertible {
    case incomplete(taskID: String, title: String, reason: String)

    public var description: String {
        switch self {
        case .incomplete(let taskID, let title, let reason):
            "task \(title.debugDescription) was saved as \(taskID), but not its block or all its subtasks: \(reason)"
        }
    }
}

extension TaskWrites {
    /// The capture panel's one write (glass-pass §4, #286): the task, then
    /// a drawn slot's block, then each subtask, all queued behind the task's
    /// `local-` id, which `OutboxWorker` rewrites once the task is accepted;
    /// a parked task parks them too. Each step saves, so a failure after
    /// the task saved leaves the task and throws `TaskCaptureError`.
    ///
    ///     try await coordinator.write {
    ///         try writes.captureTask(title: "Read chapter 4", day: "2026-09-28", filing: filing,
    ///                                details: TaskCaptureDetails(subtasks: ["Skim", "Notes"]), slot: nil)
    ///     }
    @discardableResult
    public func captureTask(
        title: String, day: String?, filing: TaskFiling, details: TaskCaptureDetails, slot: CaptureSlot?
    ) throws -> TaskRecord {
        let record = try capture(title: title, day: day, filing: filing, details: details)
        do {
            try addCaptured(slot: slot, subtasks: details.subtasks, to: record.id)
        } catch {
            throw TaskCaptureError.incomplete(taskID: record.id, title: title, reason: "\(error)")
        }
        return record
    }

    private func addCaptured(slot: CaptureSlot?, subtasks: [String], to taskID: String) throws {
        if let slot {
            _ = try BlockWrites(context: context).create(
                taskID: taskID, studyBlockID: nil, day: slot.day, start: slot.start, end: slot.end)
        }
        let writes = SubtaskWrites(context: context)
        for title in subtasks { try writes.create(taskID: taskID, title: title) }
    }
}
