import Foundation
import SwiftData
import Testing

@testable import OmakaseStore

@MainActor
struct StoreSchemaTests {
    @Test func theOnDiskStoreLivesInTheAppsOwnDirectoryIssue91() throws {
        // A default ModelConfiguration in a non-sandboxed app writes
        // "default.store" into the shared Application Support root, where
        // another app's default store can collide with it (#91).
        let root = FileManager.default.temporaryDirectory.appending(path: "omakase-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let container = try StoreSchema.container(inMemory: false, applicationSupport: root)
        let url = try #require(container.configurations.first?.url)
        #expect(url == root.appending(path: "dev.omakase.mac/Omakase.store"))
        #expect(FileManager.default.fileExists(atPath: url.path()))
    }
}
