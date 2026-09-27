import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// A class cancelled on one date and restored (#207), through the outbox.
@MainActor
struct ClassWritesTests {
    let container: ModelContainer
    let api = FakeAPIClient()
    let schedule = UUID()
    var context: ModelContext { container.mainContext }
    var writes: ClassWrites { ClassWrites(context: context) }
    var path: String { "/api/v1/study/classschedules/\(schedule.uuidString.lowercased())/cancellations/2026-09-23/" }

    init() throws { container = try StoreSchema.container(inMemory: true) }

    func entries() throws -> [OutboxEntry] {
        try context.fetch(FetchDescriptor<OutboxEntry>(sortBy: [SortDescriptor(\.sequence)]))
    }

    func seededClass(cancelled: Bool = false) throws -> ClassOccurrenceRecord {
        let record = ClassOccurrenceRecord(dto: try .make(schedule: schedule, day: "2026-09-23", cancelled: cancelled))
        context.insert(record)
        try context.save()
        return record
    }

    func drain() async -> OutboxWorker.DrainResult {
        let handlers = OutboxHandlers([ClassHandler(context: context)])
        return await OutboxWorker(context: context, api: api, handlers: handlers).drain()
    }

    @Test func cancellingShowsAtOnceAndQueuesAPut() throws {
        let occurrence = try seededClass()
        try writes.cancel(occurrence)
        let entry = try #require(try entries().first)
        #expect(occurrence.isCancelled)
        #expect(entry.kind == "class.cancel" && entry.method == "PUT" && entry.path == path)
        #expect(entry.body == nil && entry.subjectID == occurrence.id)
    }

    @Test func restoringShowsAtOnceAndQueuesADelete() throws {
        let occurrence = try seededClass(cancelled: true)
        try writes.restore(occurrence)
        let entry = try #require(try entries().first)
        #expect(!occurrence.isCancelled)
        #expect(entry.kind == "class.restore" && entry.method == "DELETE" && entry.path == path)
        #expect(entry.subjectID == occurrence.id)
    }

    @Test func aRestoreBeforeTheCancelIsSentWithdrawsBoth() async throws {
        let occurrence = try seededClass()
        try writes.cancel(occurrence)
        try writes.restore(occurrence)
        #expect(!occurrence.isCancelled)
        #expect(try entries().isEmpty)
        #expect(await drain() == .empty)
        #expect(await api.sentRequests.isEmpty)
    }

    @Test func aCancelBeforeTheRestoreIsSentWithdrawsBoth() throws {
        let occurrence = try seededClass(cancelled: true)
        try writes.restore(occurrence)
        try writes.cancel(occurrence)
        #expect(occurrence.isCancelled)
        #expect(try entries().isEmpty)
    }

    @Test func anotherClassesWriteIsNotWithdrawn() throws {
        let occurrence = try seededClass()
        let other = ClassOccurrenceRecord(dto: try .make(day: "2026-09-24"))
        context.insert(other)
        try writes.cancel(other)
        try writes.restore(occurrence)
        #expect(try entries().map(\.kind) == ["class.cancel", "class.restore"])
    }

    @Test func aCancelReplaysAndLeavesTheClassCancelled() async throws {
        let occurrence = try seededClass()
        try writes.cancel(occurrence)
        let reply = #"{"id":"\#(UUID())","class_schedule":"\#(schedule)","date":"2026-09-23","created_at":"x"}"#
        await api.script([.reply(201, reply)])
        #expect(await drain() == .empty)
        #expect(occurrence.isCancelled && (try entries().isEmpty))
        #expect(await api.sentRequests.map(\.method) == ["PUT"])
    }

    @Test func aRestoreReplaysAndLeavesTheClassRestored() async throws {
        let occurrence = try seededClass(cancelled: true)
        try writes.restore(occurrence)
        await api.script([.reply(204, "")])
        #expect(await drain() == .empty)
        #expect(!occurrence.isCancelled && (try entries().isEmpty))
        #expect(await api.sentRequests.map(\.path) == [path])
    }
}
