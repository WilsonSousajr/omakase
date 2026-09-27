import Foundation
import SwiftData

/// What signing out does to the store (#224): every record goes, the outbox
/// included, so the next account starts clean (parent spec L149-151). The
/// caller asks first, naming `unsentCount()` writes that will be lost.
///
///     let lost = try SessionReset(context: context).unsentCount()
///     try SessionReset(context: context).erase()
@MainActor
public struct SessionReset {
    private let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    /// Writes the server has not accepted: queued and parked alike.
    public func unsentCount() throws -> Int { try context.fetchCount(FetchDescriptor<OutboxEntry>()) }

    public func erase() throws {
        for model in StoreSchema.models { try erase(model) }
        try context.save()
    }

    private func erase<Model: PersistentModel>(_ type: Model.Type) throws {
        try context.delete(model: type)
    }
}
