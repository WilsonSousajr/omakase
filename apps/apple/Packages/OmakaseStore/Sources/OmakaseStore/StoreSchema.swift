import Foundation
import SwiftData

/// Every model the app persists, and the container that holds them.
///
///     let container = try StoreSchema.container(inMemory: false)
public enum StoreSchema {
    public static let models: [any PersistentModel.Type] = [TaskRecord.self, OutboxEntry.self]

    /// On disk, the store is `<Application Support>/dev.omakase.mac/Omakase.store`.
    /// A default configuration would write `default.store` into the shared
    /// Application Support root, because the app is not sandboxed (#91).
    public static func container(inMemory: Bool, applicationSupport: URL? = nil) throws -> ModelContainer {
        guard !inMemory else {
            return try ModelContainer(
                for: Schema(models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
        let root =
            try applicationSupport
            ?? FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return try ModelContainer(for: Schema(models), configurations: ModelConfiguration(url: try storeURL(in: root)))
    }

    static func storeURL(in root: URL) throws -> URL {
        let directory = root.appending(path: "dev.omakase.mac", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "Omakase.store")
    }
}
