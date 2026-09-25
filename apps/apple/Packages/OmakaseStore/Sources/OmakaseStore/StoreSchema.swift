import SwiftData

/// Every model the app persists, and the container that holds them.
///
///     let container = try StoreSchema.container(inMemory: false)
public enum StoreSchema {
    public static let models: [any PersistentModel.Type] = [TaskRecord.self, OutboxEntry.self]

    public static func container(inMemory: Bool) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: Schema(models), configurations: config)
    }
}
