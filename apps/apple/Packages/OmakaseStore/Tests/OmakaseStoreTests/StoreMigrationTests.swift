import Foundation
import SwiftData
import Testing

@testable import OmakaseStore

/// Pre-M9's `TaskRecord` shape: no `area`, `projectID` or `disciplineID`.
/// Nested so its declared Swift type doesn't collide with the module's
/// current `TaskRecord` while it persists under the same SwiftData entity
/// name, "TaskRecord" (spec §1, Review Focus 1).
private enum PreM9Schema {
    @Model
    final class TaskRecord {
        @Attribute(.unique) var id: String
        var title: String
        var priority: String
        var isCompleted: Bool
        var updatedAt: Date

        init(id: String, title: String) {
            (self.id, self.title, self.priority) = (id, title, "medium")
            (self.isCompleted, self.updatedAt) = (false, .now)
        }
    }
}

/// Whether SwiftData, given only in-process types, opens a pre-M9 store
/// under the current schema (spec §1, Review Focus 1): `area`, `projectID`
/// and `disciplineID` are new, defaulted properties, the same shape of
/// change `kanbanStatus` made without a hand-written migration.
@MainActor
struct StoreMigrationTests {
    @Test func aPreM9StoreOpensUnderTheCurrentSchemaWithDefaultedFiling() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "omakase-migration-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appending(path: "Old.store")

        let old = try ModelContainer(
            for: Schema([PreM9Schema.TaskRecord.self]), configurations: ModelConfiguration(url: url))
        old.mainContext.insert(PreM9Schema.TaskRecord(id: "old-1", title: "Before M9"))
        try old.mainContext.save()

        let current = try ModelContainer(for: Schema(StoreSchema.models), configurations: ModelConfiguration(url: url))
        let record = try #require(try current.mainContext.fetch(FetchDescriptor<TaskRecord>()).first)
        #expect(record.title == "Before M9")
        #expect(record.filing == TaskFiling(area: .work, parent: nil))
    }
}
