import Foundation
import OmakaseAPI
import SwiftData

/// A pomodoro as it ran on the Mac. The server records it; it never drives
/// the clock (spec, The app on macOS). Its task is passed to `record` as the
/// record itself, not an id (see there).
public struct FinishedSession: Sendable, Equatable {
    public let timeBlockID: String?
    public let type: String
    public let minutes: Int
    public let startedAt: Date
    public let endedAt: Date
    public let completed: Bool

    public init(timeBlockID: String?, type: String, minutes: Int, startedAt: Date, endedAt: Date, completed: Bool) {
        (self.timeBlockID, self.type, self.minutes) = (timeBlockID, type, minutes)
        (self.startedAt, self.endedAt, self.completed) = (startedAt, endedAt, completed)
    }
}

/// Posts a finished session with the Mac's clock and its block (#142).
///
///     try SessionWrites(context: ctx).record(finished, task: record)
@MainActor
public final class SessionWrites {
    private let context: ModelContext
    private let queue: OutboxQueue

    public init(context: ModelContext) { (self.context, queue) = (context, OutboxQueue(context: context)) }

    /// `task` is read at recording time, not when the pomodoro started: a
    /// task captured offline may have taken its server id meanwhile, and a
    /// stale `local-` id would park the session (final review, Important 2).
    public func record(_ session: FinishedSession, task: TaskRecord?) throws {
        let body = SessionBody(
            task: task?.id, timeBlock: session.timeBlockID, sessionType: session.type,
            durationMinutes: session.minutes, startedAt: session.startedAt, endedAt: session.endedAt,
            completed: session.completed)
        // No subject: no local record depends on a session's reply.
        try queue.enqueue(
            kind: "session.create", method: "POST", path: "/api/v1/pomodoro/sessions/",
            body: try OmakaseJSON.encoder.encode(body), subjectID: nil)
        try context.save()
    }

    /// On a create, a missing `task` or `time_block` means "none", so nils may be omitted.
    private struct SessionBody: Encodable {
        let task: String?
        let timeBlock: String?
        let sessionType: String
        let durationMinutes: Int
        let startedAt: Date
        let endedAt: Date
        let completed: Bool
    }
}

/// Sessions are not cached until M3.3 shows their history, so an accepted
/// session changes nothing locally; the handler exists so the kind is known.
@MainActor
public final class SessionHandler: OutboxHandler {
    public let kinds = ["session.create"]

    public init() {}

    public func apply(_ entry: OutboxEntry, body: Data) {}
}
