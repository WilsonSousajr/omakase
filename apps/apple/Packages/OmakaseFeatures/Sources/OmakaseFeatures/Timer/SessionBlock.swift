/// Which of a task's blocks today a session records against (#129): the one
/// covering now, else the next one today, else none.
///
///     SessionBlock.pick(for: taskID, in: slots, at: "14:20")
public enum SessionBlock {
    /// A block's id, task and `HH:MM:SS` times, as the store holds them.
    public struct Slot: Equatable, Sendable {
        public let id: String
        public let taskID: String?
        public let start: String
        public let end: String

        public init(id: String, taskID: String?, start: String, end: String) {
            (self.id, self.taskID, self.start, self.end) = (id, taskID, start, end)
        }
    }

    /// `time` is `HH:MM`; times compare as strings because they are zero-padded.
    public static func pick(for taskID: String, in slots: [Slot], at time: String) -> String? {
        let own = slots.filter { $0.taskID == taskID }.sorted { $0.start < $1.start }
        if let covering = own.first(where: { $0.start.prefix(5) <= time && time < $0.end.prefix(5) }) {
            return covering.id
        }
        return own.first { $0.start.prefix(5) > time }?.id
    }
}
