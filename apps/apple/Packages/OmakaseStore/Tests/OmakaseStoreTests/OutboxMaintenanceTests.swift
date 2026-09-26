import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

@MainActor
struct OutboxMaintenanceTests {
    let container: ModelContainer
    let api = FakeAPIClient()
    let start = Date(timeIntervalSince1970: 1_772_884_800)
    var context: ModelContext { container.mainContext }
    var maintenance: OutboxMaintenance { OutboxMaintenance(context: context) }

    init() throws { container = try StoreSchema.container(inMemory: true) }

    func worker() -> OutboxWorker {
        OutboxWorker(
            context: context, api: api, clock: { [start] in start }, handlers: OutboxHandlers([RecordingHandler()]))
    }

    @discardableResult
    func enqueue(_ sequence: Int, _ path: String, creates: String? = nil) -> OutboxEntry {
        let entry = OutboxEntry(
            sequence: sequence, method: creates == nil ? "PATCH" : "POST", path: path, body: nil,
            subjectID: creates, createsLocalID: creates, kind: creates == nil ? "task.patch" : "task.create",
            now: start)
        context.insert(entry)
        return entry
    }

    func remaining() throws -> [OutboxEntry] {
        try context.fetch(FetchDescriptor<OutboxEntry>(sortBy: [SortDescriptor(\.sequence)]))
    }

    @Test func anEmptyOutboxHasNothingToShow() {
        #expect(maintenance.status() == OutboxStatus(pendingCount: 0, parked: [], nextAttemptAt: nil))
    }

    @Test func statusCountsPendingAndListsParked() throws {
        enqueue(1, "/a/")
        enqueue(2, "/b/").nextAttemptAt = start.addingTimeInterval(8)
        enqueue(3, "/c/").nextAttemptAt = start.addingTimeInterval(2)
        let parked = enqueue(4, "/d/")
        (parked.state, parked.lastError) = (.parked, "title required")
        let status = maintenance.status()
        #expect(status.pendingCount == 3)
        #expect(status.nextAttemptAt == start.addingTimeInterval(2))
        #expect(
            status.parked == [
                ParkedWrite(
                    sequence: 4, kind: "task.patch", subjectID: nil, lastError: "title required", createdAt: start,
                    method: "PATCH", path: "/d/")
            ])
    }

    @Test func aRetriedParkedWriteIsSentAgain() async throws {
        enqueue(1, "/a/")
        await api.script([.reply(400, #"{"detail":"title required"}"#), .reply(200, "{}")])
        _ = await worker().drain()
        let parked = try #require(try remaining().first)
        parked.attempts = 3
        try maintenance.retry(sequence: 1)
        #expect(parked.state == .pending && parked.attempts == 0)
        #expect(parked.lastError == nil && parked.nextAttemptAt == nil)
        #expect(await worker().drain() == .empty)
        #expect(await api.sentRequests.map(\.path) == ["/a/", "/a/"])
        #expect(try remaining().isEmpty)
    }

    @Test func retryingACreateUnparksItsDependents() async throws {
        let serverID = "9F1C0000-0000-0000-0000-000000000000"
        enqueue(1, "/api/v1/tasks/", creates: "local-1")
        enqueue(2, "/api/v1/tasks/local-1/")
        enqueue(3, "/other/")
        await api.script([.reply(400, #"{"detail":"bad"}"#), .reply(400, #"{"detail":"own"}"#)])
        _ = await worker().drain()
        try maintenance.retry(sequence: 1)
        #expect(try remaining().map(\.state) == [.pending, .pending, .parked])
        await api.script([.reply(201, #"{"id":"\#(serverID)"}"#), .reply(200, "{}")])
        #expect(await worker().drain() == .empty)
        #expect(await api.sentRequests.suffix(2).map(\.path) == ["/api/v1/tasks/", "/api/v1/tasks/\(serverID)/"])
    }

    @Test func retryingAnUnknownWriteSaysWhichOne() {
        #expect(throws: OutboxMaintenance.Failure.noEntry(sequence: 7)) { try maintenance.retry(sequence: 7) }
        #expect("\(OutboxMaintenance.Failure.noEntry(sequence: 7))".contains("7"))
    }
}
