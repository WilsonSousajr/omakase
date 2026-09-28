import Foundation
import SwiftData

/// The running pomodoro, encoded by Features. One row: the store keeps the
/// bytes and knows nothing of timer rules (spec: the timer survives a quit).
@Model
public final class TimerStateRecord {
    @Attribute(.unique) public var key: String = "timer"
    public var data: Data

    public init(data: Data) { self.data = data }
}

/// Saves and loads the timer's state.
///
///     try TimerStateStore(context: ctx).save(encodedState)
@MainActor
public struct TimerStateStore {
    private let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    public func load() -> Data? {
        (try? context.fetch(FetchDescriptor<TimerStateRecord>()))?.first?.data
    }

    public func save(_ data: Data) throws {
        if let record = try context.fetch(FetchDescriptor<TimerStateRecord>()).first {
            record.data = data
        } else {
            context.insert(TimerStateRecord(data: data))
        }
        try context.save()
    }
}
