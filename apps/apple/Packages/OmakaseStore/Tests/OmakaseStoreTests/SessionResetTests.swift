import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// Signing out erases the cache and the outbox, so the next account starts
/// clean (M5 spec, Decisions; parent spec L149-151).
@MainActor
struct SessionResetTests {
    @Test func erasingLeavesNoRecordOfAnyKind() throws {
        let container = try StoreSchema.container(inMemory: true)
        let context = container.mainContext
        let task = TaskRecord(dto: try .make(title: "Mine"))
        context.insert(task)
        try TaskWrites(context: context).toggleCompletion(task)
        context.insert(WorkspaceRecord(dto: try LibrarySample.workspace()))
        try context.save()
        try SessionReset(context: context).erase()
        #expect(try context.fetchCount(FetchDescriptor<TaskRecord>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<OutboxEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WorkspaceRecord>()) == 0)
    }

    @Test func theUnsentCountIsWhatSigningOutWouldLose() throws {
        let container = try StoreSchema.container(inMemory: true)
        let context = container.mainContext
        let task = TaskRecord(dto: try .make(title: "Mine"))
        context.insert(task)
        try TaskWrites(context: context).toggleCompletion(task)
        #expect(try SessionReset(context: context).unsentCount() == 1)
    }
}
