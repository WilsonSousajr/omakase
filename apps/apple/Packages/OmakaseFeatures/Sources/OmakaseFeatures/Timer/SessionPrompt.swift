import Foundation

/// The end-of-focus prompt (decided with the user): an optional 1-5 rating
/// and "What did you accomplish?", prefilled with the task's checked
/// subtasks, saved to the task's block. No block, no prompt: the session is
/// still recorded.
///
///     let prompt = SessionPrompt.make(for: timer.lastFinished, taskTitle: title, doneSubtasks: done)
public struct SessionPrompt: Identifiable, Equatable, Sendable {
    /// A block write the prompt asks for.
    public enum Write: Equatable, Sendable {
        case rate(String, Int)
        case notes(String, String)
    }

    public let blockID: String
    public let taskTitle: String
    public let prefill: String
    public var id: String { blockID }

    public init(blockID: String, taskTitle: String, prefill: String) {
        (self.blockID, self.taskTitle, self.prefill) = (blockID, taskTitle, prefill)
    }

    public static func make(
        for finished: CompletedPhase?, taskTitle: String?, doneSubtasks: [String]
    ) -> SessionPrompt? {
        guard let finished, finished.phase == .focus, finished.completed, let blockID = finished.blockID else {
            return nil
        }
        let prefill = doneSubtasks.map { "✓ \($0)" }.joined(separator: "\n")
        return SessionPrompt(blockID: blockID, taskTitle: taskTitle ?? "Focus", prefill: prefill)
    }

    /// The writes for what was entered; nothing for what was left empty.
    public func writes(rating: Int?, notes: String) -> [Write] {
        var writes: [Write] = []
        if let rating { writes.append(.rate(blockID, rating)) }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { writes.append(.notes(blockID, trimmed)) }
        return writes
    }
}
