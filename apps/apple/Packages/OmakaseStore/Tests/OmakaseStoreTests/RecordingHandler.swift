import Foundation

@testable import OmakaseStore

/// A named fake handler: accepts the task kinds and records each reply it is
/// given, so worker tests can see what was accepted without a real store update.
@MainActor
final class RecordingHandler: OutboxHandler {
    let kinds: [String]
    private(set) var received: [String] = []

    init(kinds: [String] = ["task.patch", "task.create"]) { self.kinds = kinds }

    func apply(_ entry: OutboxEntry, body: Data) {
        received.append("\(entry.path) \(String(bytes: body, encoding: .utf8) ?? "")")
    }
}
