import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

@MainActor
struct OutboxWorkerTests {
    let container: ModelContainer
    let api = FakeAPIClient()
    let start = Date(timeIntervalSince1970: 1_772_884_800)
    var context: ModelContext { container.mainContext }

    init() throws { container = try StoreSchema.container(inMemory: true) }

    func worker(now: Date? = nil) -> OutboxWorker {
        let fixed = now ?? start
        return OutboxWorker(
            context: context, api: api, clock: { fixed }, handlers: OutboxHandlers([RecordingHandler()]))
    }

    func enqueue(_ sequence: Int, _ path: String, creates: String? = nil) {
        context.insert(
            OutboxEntry(
                sequence: sequence, method: creates == nil ? "PATCH" : "POST", path: path, body: nil,
                subjectID: creates, createsLocalID: creates))
    }

    func remaining() throws -> [OutboxEntry] {
        try context.fetch(FetchDescriptor<OutboxEntry>(sortBy: [SortDescriptor(\.sequence)]))
    }

    @Test func sendsInSequenceOrderAndDeletesAccepted() async throws {
        enqueue(2, "/b/")
        enqueue(1, "/a/")
        await api.script([.reply(200, "{}"), .reply(200, "{}")])
        #expect(await worker().drain() == .empty)
        #expect(await api.sentRequests.map(\.path) == ["/a/", "/b/"])
        #expect(try remaining().isEmpty)
    }

    @Test func offlineKeepsTheEntryAndBacksOff() async throws {
        enqueue(1, "/a/")
        await api.script([.offline])
        #expect(await worker().drain() == .waiting(until: start.addingTimeInterval(1)))
        let entry = try #require(try remaining().first)
        #expect(entry.attempts == 1 && entry.state == .pending && entry.lastError == "offline")
        #expect(await worker(now: start).drain() == .waiting(until: start.addingTimeInterval(1)))
        #expect(await api.sentRequests.count == 1)
    }

    @Test func a400ParksAndLaterEntriesContinue() async throws {
        enqueue(1, "/a/")
        enqueue(2, "/b/")
        await api.script([.reply(400, #"{"detail":"title required"}"#), .reply(200, "{}")])
        #expect(await worker().drain() == .empty)
        let parked = try #require(try remaining().first)
        #expect(parked.state == .parked && parked.lastError == "title required" && parked.path == "/a/")
        #expect(try remaining().count == 1)
    }

    @Test func aParkedCreateParksItsDependents() async throws {
        enqueue(1, "/api/v1/tasks/", creates: "local-1")
        enqueue(2, "/api/v1/tasks/local-1/")
        await api.script([.reply(400, #"{"detail":"bad"}"#)])
        _ = await worker().drain()
        #expect(try remaining().map(\.state) == [.parked, .parked])
        #expect(await api.sentRequests.count == 1)
    }

    @Test func anAcceptedCreateRewritesLaterPlaceholders() async throws {
        let serverID = "9F1C0000-0000-0000-0000-000000000000"
        enqueue(1, "/api/v1/tasks/", creates: "local-1")
        enqueue(2, "/api/v1/tasks/local-1/")
        await api.script([.reply(201, #"{"id":"\#(serverID)"}"#), .reply(200, "{}")])
        _ = await worker().drain()
        #expect(await api.sentRequests.map(\.path) == ["/api/v1/tasks/", "/api/v1/tasks/\(serverID)/"])
    }

    @Test func signedOutPausesAndKeepsTheQueue() async throws {
        // Review Focus 4: the refresh token expired offline.
        enqueue(1, "/a/")
        enqueue(2, "/b/")
        await api.script([.signedOut])
        #expect(await worker().drain() == .signedOut)
        #expect(try remaining().count == 2)
    }

    @Test func theIdempotencyKeyIsStableAcrossRetries() async throws {
        enqueue(1, "/a/")
        await api.script([.offline, .reply(200, "{}")])
        _ = await worker().drain()
        _ = await worker(now: start.addingTimeInterval(2)).drain()
        let keys = await api.sentRequests.map(\.idempotencyKey)
        #expect(keys.count == 2 && keys[0] == keys[1])
    }

    @Test func acceptedEntriesReachTheCallbackWithTheServersBody() async throws {
        enqueue(1, "/a/")
        await api.script([.reply(200, #"{"ok":true}"#)])
        let recorder = RecordingHandler()
        let worker = OutboxWorker(
            context: context, api: api, clock: { [start] in start }, handlers: OutboxHandlers([recorder]))
        _ = await worker.drain()
        #expect(recorder.received == [#"/a/ {"ok":true}"#])
    }

    @Test func concurrentDrainsSendEachEntryOnce() async throws {
        // Review finding C2: reachability, the 5-minute loop and sign-in can
        // all drain at once. drain() suspends at send() with the entry still
        // pending, so a second drain used to send the same entry again.
        enqueue(1, "/a/")
        enqueue(2, "/b/")
        await api.script([.reply(200, "{}"), .reply(200, "{}"), .reply(200, "{}"), .reply(200, "{}")])
        let shared = worker()
        async let first = shared.drain()
        async let second = shared.drain()
        _ = await (first, second)
        #expect(await api.sentRequests.map(\.path) == ["/a/", "/b/"])
        #expect(try remaining().isEmpty)
    }
}
