import Foundation

/// The backend-written contract fixtures in apps/apple/Fixtures (#78).
enum Fixture {
    static func data(_ name: String) throws -> Data {
        // Tests/OmakaseAPITests/Fixture.swift -> apps/apple/Fixtures/<name>.json
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try Data(contentsOf: root.appending(path: "Fixtures/\(name).json"))
    }
}
