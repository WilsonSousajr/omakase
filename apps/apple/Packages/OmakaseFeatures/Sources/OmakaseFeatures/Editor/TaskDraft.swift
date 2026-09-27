import Foundation
import OmakaseStore

/// A task's editable fields as the editor holds them (#218): a value, so the
/// edit is the difference between two drafts and can be tested without a store.
///
///     TaskDraft(record: record).changes(from: original)
public struct TaskDraft: Equatable, Sendable {
    /// The server's choices, lowest first.
    public static let priorities = ["low", "medium", "high", "urgent"]

    public var title: String
    public var notes: String
    public var priority: String
    public var estimate: Int?
    public var dueDay: String?

    public init(title: String, notes: String, priority: String, estimate: Int?, dueDay: String?) {
        (self.title, self.notes, self.priority) = (title, notes, priority)
        (self.estimate, self.dueDay) = (estimate, dueDay)
    }

    @MainActor
    public init(record: TaskRecord) {
        self.init(
            title: record.title, notes: record.notes, priority: record.priority, estimate: record.estimatedMinutes,
            dueDay: record.dueDay)
    }

    /// The title as it would be saved: surrounding whitespace dropped.
    public var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// What differs from `original`; a removed estimate or due date is a clear.
    public func changes(from original: TaskDraft) -> TaskEdit {
        TaskEdit(
            title: trimmedTitle == original.title ? nil : trimmedTitle,
            notes: notes == original.notes ? nil : notes,
            priority: priority == original.priority ? nil : priority,
            estimate: Self.clearable(estimate, was: original.estimate),
            dueDay: Self.clearable(dueDay, was: original.dueDay))
    }

    private static func clearable<Value>(_ value: Value?, was old: Value?) -> TaskEdit.Clearable<Value>? {
        guard value != old else { return nil }
        return value.map { .set($0) } ?? .clear
    }
}
