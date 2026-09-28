import Foundation

/// Applies an accepted write's reply to the store. One per kind of write
/// (M3.1 spec §3), so a new kind is a new small type, not a longer switch.
@MainActor
public protocol OutboxHandler {
    var kinds: [String] { get }
    func apply(_ entry: OutboxEntry, body: Data)
}

/// The handlers the worker looks writes up in.
///
///     OutboxHandlers([TaskHandler(context: ctx), ReviewHandler(context: ctx)])
@MainActor
public struct OutboxHandlers {
    private let byKind: [String: any OutboxHandler]

    public init(_ handlers: [any OutboxHandler]) {
        var byKind: [String: any OutboxHandler] = [:]
        for handler in handlers {
            for kind in handler.kinds { byKind[kind] = handler }
        }
        self.byKind = byKind
    }

    public func handles(_ kind: String) -> Bool { byKind[kind] != nil }

    public func apply(_ entry: OutboxEntry, body: Data) { byKind[entry.kind]?.apply(entry, body: body) }
}
