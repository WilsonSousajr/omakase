import Foundation
import OmakaseAPI
import SwiftData

/// A project edit (#226): nil leaves a field; a due date is set or cleared.
public struct ProjectEdit: Equatable, Sendable, Encodable {
    public var name: String?
    public var color: String?
    /// active, paused, completed or archived.
    public var status: String?
    public var dueDay: TaskEdit.Clearable<String>?

    public init(
        name: String? = nil, color: String? = nil, status: String? = nil, dueDay: TaskEdit.Clearable<String>? = nil
    ) {
        (self.name, self.color, self.status, self.dueDay) = (name, color, status, dueDay)
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case color
        case status
        case dueDay = "due_date"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(status, forKey: .status)
        guard let dueDay else { return }
        if let day = dueDay.value {
            try container.encode(day, forKey: .dueDay)
        } else {
            try container.encodeNil(forKey: .dueDay)
        }
    }
}

/// Workspaces and projects, written online through `DirectWrites` (#226;
/// parent spec L136-139). The server cascades a workspace's projects when
/// it goes, and so does the cache; their tasks stay, without a project.
///
///     let workspace = try await ProjectWrites(api: api, context: context)
///         .createWorkspace(name: "Client work", color: "#3b82f6")
@MainActor
public struct ProjectWrites {
    private let writes: DirectWrites
    private let context: ModelContext

    public init(api: any APIClient, context: ModelContext) {
        (writes, self.context) = (DirectWrites(api: api, context: context), context)
    }

    public func createWorkspace(name: String, color: String) async throws -> WorkspaceRecord {
        let fields = ["name": name, "color": color]
        return try await writes.save(WorkspaceRecord.self, "POST", "/api/v1/workspaces/", body: try body(fields))
    }

    public func renameWorkspace(_ workspace: WorkspaceRecord, to name: String) async throws {
        try await writes.save(WorkspaceRecord.self, "PATCH", Self.path(workspace), body: try body(["name": name]))
    }

    public func deleteWorkspace(_ workspace: WorkspaceRecord) async throws {
        let id = workspace.id
        try await writes.delete(workspace, path: Self.path(workspace))
        let projects = try context.fetch(FetchDescriptor<ProjectRecord>(predicate: #Predicate { $0.workspaceID == id }))
        for project in projects { context.delete(project) }
        try context.save()
    }

    public func createProject(
        in workspace: WorkspaceRecord, name: String, color: String
    ) async throws -> ProjectRecord {
        let fields = ["workspace": workspace.id.lowercased(), "name": name, "color": color, "status": "active"]
        return try await writes.save(ProjectRecord.self, "POST", "/api/v1/projects/", body: try body(fields))
    }

    public func editProject(_ project: ProjectRecord, _ edit: ProjectEdit) async throws {
        let path = "/api/v1/projects/\(project.id.lowercased())/"
        try await writes.save(ProjectRecord.self, "PATCH", path, body: try JSONEncoder().encode(edit))
    }

    public func deleteProject(_ project: ProjectRecord) async throws {
        try await writes.delete(project, path: "/api/v1/projects/\(project.id.lowercased())/")
    }

    private func body(_ fields: [String: String]) throws -> Data { try JSONEncoder().encode(fields) }

    private static func path(_ workspace: WorkspaceRecord) -> String {
        "/api/v1/workspaces/\(workspace.id.lowercased())/"
    }
}
