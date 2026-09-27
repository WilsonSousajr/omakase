import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// Library writes are online-only (M5 spec, Decisions): sent now, applied to
/// the cache from the reply, never queued.
@MainActor
struct DirectWritesTests {
    let container: ModelContainer
    let api = FakeAPIClient()

    init() throws { container = try StoreSchema.container(inMemory: true) }

    private var context: ModelContext { container.mainContext }
    private var writes: DirectWrites { DirectWrites(api: api, context: context) }
    private let workspaceJSON =
        ##"{"id":"11111111-1111-1111-1111-111111111111","name":"Client work","color":"#a3a3a3","project_count":0}"##
    private let body = Data(#"{"name":"Client work"}"#.utf8)

    @Test func aCreateIsSentNowAndCachedFromTheReply() async throws {
        await api.script([.reply(201, workspaceJSON)])
        let record = try await writes.save(WorkspaceRecord.self, "POST", "/api/v1/workspaces/", body: body)
        #expect(record.name == "Client work")
        #expect(try context.fetch(FetchDescriptor<WorkspaceRecord>()).count == 1)
        let sent = try #require(await api.sentRequests.first)
        #expect(sent.method == "POST" && sent.path == "/api/v1/workspaces/" && sent.body == body)
        #expect(try context.fetch(FetchDescriptor<OutboxEntry>()).isEmpty)
    }

    @Test func anUpdateAppliesTheReplyToTheCachedRecord() async throws {
        await api.script([.reply(201, workspaceJSON), .reply(200, workspaceJSON.replacingOccurrences(of: "Client work", with: "Renamed"))])
        let path = "/api/v1/workspaces/11111111-1111-1111-1111-111111111111/"
        try await writes.save(WorkspaceRecord.self, "POST", "/api/v1/workspaces/", body: body)
        try await writes.save(WorkspaceRecord.self, "PATCH", path, body: body)
        #expect(try context.fetch(FetchDescriptor<WorkspaceRecord>()).map(\.name) == ["Renamed"])
    }

    @Test func aDeleteRemovesTheRecordOnceTheServerHas() async throws {
        await api.script([.reply(201, workspaceJSON), .reply(204, "")])
        let record = try await writes.save(WorkspaceRecord.self, "POST", "/api/v1/workspaces/", body: body)
        try await writes.delete(record, path: "/api/v1/workspaces/\(record.id.lowercased())/")
        #expect(try context.fetch(FetchDescriptor<WorkspaceRecord>()).isEmpty)
        #expect(await api.sentRequests.last?.path == "/api/v1/workspaces/11111111-1111-1111-1111-111111111111/")
    }

    @Test func aRefusalCarriesTheServersFieldMessagesAndCachesNothing() async throws {
        await api.script([.reply(400, #"{"name":["This field is required."],"color":["Enter a hex colour."]}"#)])
        await #expect(throws: DirectWrites.Failure.rejected("color: Enter a hex colour. name: This field is required.")) {
            try await writes.save(WorkspaceRecord.self, "POST", "/api/v1/workspaces/", body: body)
        }
        #expect(try context.fetch(FetchDescriptor<WorkspaceRecord>()).isEmpty)
    }

    @Test func aDetailMessageIsUsedAsIs() {
        #expect(ServerMessage.read(Data(#"{"detail":"Not found."}"#.utf8), status: 404) == "Not found.")
        #expect(ServerMessage.read(Data("<html>".utf8), status: 502) == "HTTP 502")
    }

    @Test func offlineNothingIsQueuedOrCached() async throws {
        await api.script([.offline])
        await #expect(throws: DirectWrites.Failure.offline) {
            try await writes.save(WorkspaceRecord.self, "POST", "/api/v1/workspaces/", body: body)
        }
        #expect(try context.fetch(FetchDescriptor<OutboxEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WorkspaceRecord>()).isEmpty)
    }

    @Test func aSignedOutReplyIsNamed() async throws {
        await api.script([.signedOut])
        await #expect(throws: DirectWrites.Failure.signedOut) {
            try await writes.save(WorkspaceRecord.self, "POST", "/api/v1/workspaces/", body: body)
        }
    }
}
