import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// Workspaces and projects, written online (#226): the request each edit
/// sends, and the cache after the server's reply.
@MainActor
struct ProjectWritesTests {
    let container: ModelContainer
    let api = FakeAPIClient()

    init() throws { container = try StoreSchema.container(inMemory: true) }

    private var context: ModelContext { container.mainContext }
    private var writes: ProjectWrites { ProjectWrites(api: api, context: context) }
    private let workspaceID = LibrarySample.workspaceID
    private let projectID = "44444444-4444-4444-4444-444444444444"

    private func workspaceJSON(_ name: String = "Client work") -> String {
        ##"{"id":"\##(workspaceID)","name":"\##(name)","color":"#3b82f6","project_count":0}"##
    }

    private func projectJSON(status: String = "active", due: String = "null") -> String {
        ##"{"id":"\##(projectID)","workspace":"\##(workspaceID)","name":"Thesis","description":"","##
            + ##""color":"#3b82f6","status":"\##(status)","due_date":\##(due),"task_count":0}"##
    }

    private func lastBody() async throws -> [String: Any] {
        let body = try #require(await api.sentRequests.last?.body)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    @Test func aWorkspaceIsCreatedWithItsNameAndColour() async throws {
        await api.script([.reply(201, workspaceJSON())])
        let workspace = try await writes.createWorkspace(name: "Client work", color: "#3b82f6")
        #expect(workspace.name == "Client work")
        #expect(await api.sentRequests.last?.path == "/api/v1/workspaces/")
        #expect(try await lastBody() as? [String: String] == ["name": "Client work", "color": "#3b82f6"])
    }

    @Test func renamingPatchesOnlyTheName() async throws {
        await api.script([.reply(201, workspaceJSON()), .reply(200, workspaceJSON("Clients"))])
        let workspace = try await writes.createWorkspace(name: "Client work", color: "#3b82f6")
        try await writes.renameWorkspace(workspace, to: "Clients")
        let sent = try #require(await api.sentRequests.last)
        #expect(sent.method == "PATCH" && sent.path == "/api/v1/workspaces/\(workspaceID)/")
        #expect(try await lastBody() as? [String: String] == ["name": "Clients"])
        #expect(workspace.name == "Clients")
    }

    @Test func deletingAWorkspaceDropsItsProjectsFromTheCache() async throws {
        await api.script([.reply(201, workspaceJSON()), .reply(201, projectJSON()), .reply(204, "")])
        let workspace = try await writes.createWorkspace(name: "Client work", color: "#3b82f6")
        _ = try await writes.createProject(in: workspace, name: "Thesis", color: "#3b82f6")
        try await writes.deleteWorkspace(workspace)
        #expect(try context.fetchCount(FetchDescriptor<WorkspaceRecord>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ProjectRecord>()) == 0)
    }

    @Test func aProjectIsCreatedActiveInItsWorkspace() async throws {
        await api.script([.reply(201, workspaceJSON()), .reply(201, projectJSON())])
        let workspace = try await writes.createWorkspace(name: "Client work", color: "#3b82f6")
        let project = try await writes.createProject(in: workspace, name: "Thesis", color: "#3b82f6")
        #expect(project.workspaceID == workspaceID.uppercased() && project.status == "active")
        let body = try await lastBody()
        #expect(body["workspace"] as? String == workspaceID.lowercased() && body["status"] as? String == "active")
    }

    @Test func anEditSendsWhatChangedAndClearsADueDateWithNull() async throws {
        await api.script([
            .reply(201, workspaceJSON()), .reply(201, projectJSON(due: "\"2026-12-01\"")),
            .reply(200, projectJSON(status: "paused")),
        ])
        let workspace = try await writes.createWorkspace(name: "Client work", color: "#3b82f6")
        let project = try await writes.createProject(in: workspace, name: "Thesis", color: "#3b82f6")
        try await writes.editProject(project, ProjectEdit(status: "paused", dueDay: .clear))
        let body = try await lastBody()
        #expect(Set(body.keys) == ["status", "due_date"] && body["due_date"] is NSNull)
        #expect(project.status == "paused" && project.dueDay == nil)
    }
}
