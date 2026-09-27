import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// The task's description is cached as `notes`, so the editor (#218) can show
/// and change it offline.
@MainActor
struct TaskNotesTests {
    @Test func aRecordCachesTheServersDescription() throws {
        let record = TaskRecord(dto: try .make(description: "Chapter 3 first"))
        #expect(record.notes == "Chapter 3 first")
    }

    @Test func applyingAServerCopyReplacesTheNotes() throws {
        let record = TaskRecord(dto: try .make(description: "Old"))
        record.apply(try .make(description: "New"))
        #expect(record.notes == "New")
    }

    @Test func aLocalRecordStartsWithNoNotes() {
        #expect(TaskRecord(id: "local-1", title: "Captured").notes.isEmpty)
    }
}
