import Foundation
import OmakaseStore

/// What ⌘E opens in the capture panel (glass-pass §4, #286), as the panel
/// holds it: a value, so a save's payload is tested without a view.
///
///     CaptureDetails(date: "2026-09-30", priority: "high", subtasks: ["Outline", ""])
public struct CaptureDetails: Equatable, Sendable {
    /// A picked day, `YYYY-MM-DD`, which replaces where ⏎ saves; nil keeps the context's.
    public var date: String?
    /// nil until chosen, which leaves the server's default, Medium.
    public var priority: String?
    public var estimateMinutes: Int?
    /// The task's `description`, as the editor calls it.
    public var notes: String
    /// One per line, as typed: there is always a line to type into, and
    /// blank lines are dropped on save.
    public var subtasks: [String]

    public init(
        date: String? = nil, priority: String? = nil, estimateMinutes: Int? = nil, notes: String = "",
        subtasks: [String] = [""]
    ) {
        (self.date, self.priority, self.estimateMinutes) = (date, priority, estimateMinutes)
        (self.notes, self.subtasks) = (notes, subtasks)
    }

    /// What a save sends: notes and titles trimmed, blank ones dropped, and
    /// an unset field left out, so the create keeps the server's default.
    var taskDetails: TaskCaptureDetails {
        let notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let titles = subtasks.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return TaskCaptureDetails(
            priority: priority, estimatedMinutes: estimateMinutes, notes: notes.isEmpty ? nil : notes,
            subtasks: titles)
    }
}

/// Whether the capture panel opens expanded (glass-pass §4), as
/// UserDefaults' `omakase.capture.expanded` holds it: a stored Bool, with a
/// missing or unreadable value read as collapsed, the quick path.
///
///     CaptureExpansion.isExpanded(stored: defaults.object(forKey: "omakase.capture.expanded"))
public enum CaptureExpansion {
    public static func isExpanded(stored: Any?) -> Bool { (stored as? Bool) ?? false }
}
