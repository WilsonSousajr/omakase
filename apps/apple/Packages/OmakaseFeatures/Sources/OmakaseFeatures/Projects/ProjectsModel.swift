import Foundation
import Observation
import OmakaseStore

/// A project as the Projects screen shows it (#226).
public struct ProjectCard: Identifiable, Equatable, Sendable {
    public let id: String
    public let workspaceID: String
    public let name: String
    public let color: String
    /// active, paused, completed or archived.
    public let status: String
    public let taskCount: Int

    public init(id: String, workspaceID: String, name: String, color: String, status: String, taskCount: Int) {
        (self.id, self.workspaceID, self.name, self.color) = (id, workspaceID, name, color)
        (self.status, self.taskCount) = (status, taskCount)
    }

    @MainActor
    public init(record: ProjectRecord) {
        self.init(
            id: record.id, workspaceID: record.workspaceID, name: record.name, color: record.color,
            status: record.status, taskCount: record.taskCount)
    }
}

/// Projects (#226): workspaces and their projects, written online (parent
/// spec L136-139). A failure is said at the foot until the next success; a
/// delete asks first and says what goes with it (the server's CASCADE and
/// SET_NULL).
///
///     await projects.createProject(name: "Thesis", in: workspaceID, existing: 2)
@Observable
@MainActor
public final class ProjectsModel {
    public struct Actions {
        let createWorkspace: (String, String) async throws -> Void
        let renameWorkspace: (String, String) async throws -> Void
        let deleteWorkspace: (String) async throws -> Void
        let createProject: (String, String, String) async throws -> Void
        let editProject: (String, ProjectEdit) async throws -> Void
        let deleteProject: (String) async throws -> Void

        public init(
            createWorkspace: @escaping (String, String) async throws -> Void,
            renameWorkspace: @escaping (String, String) async throws -> Void,
            deleteWorkspace: @escaping (String) async throws -> Void,
            createProject: @escaping (String, String, String) async throws -> Void,
            editProject: @escaping (String, ProjectEdit) async throws -> Void,
            deleteProject: @escaping (String) async throws -> Void
        ) {
            (self.createWorkspace, self.renameWorkspace, self.deleteWorkspace) = (
                createWorkspace, renameWorkspace, deleteWorkspace
            )
            (self.createProject, self.editProject, self.deleteProject) = (createProject, editProject, deleteProject)
        }
    }

    /// What a delete would take; asked before it is sent.
    public enum Deletion: Equatable, Sendable {
        case workspace(id: String, name: String)
        case project(id: String, name: String)

        public var warning: String {
            switch self {
            case .workspace: "Its projects go too. Their tasks stay, without a project."
            case .project: "Its tasks stay, without a project."
            }
        }
    }

    /// Source colours for calendar blocks (design-system-apple, Signals).
    public static let palette = [
        "#6b7280", "#3b82f6", "#22c55e", "#f59e0b", "#ef4444", "#14b8a6", "#ec4899", "#f97316",
    ]
    public static let statuses = ["active", "paused", "completed", "archived"]

    /// nil is All.
    public var selectedWorkspaceID: String?
    public private(set) var message: String?
    public private(set) var deleting: Deletion?

    @ObservationIgnored private let actions: Actions

    public init(actions: Actions) { self.actions = actions }

    public func visible(_ cards: [ProjectCard]) -> [ProjectCard] {
        guard let selectedWorkspaceID else { return cards }
        return cards.filter { $0.workspaceID == selectedWorkspaceID }
    }

    /// `existing` picks the next colour, so neighbours differ.
    public func createWorkspace(name: String, existing: Int) async {
        guard let name = Self.trimmed(name) else { return }
        await run { try await self.actions.createWorkspace(name, Self.colour(after: existing)) }
    }

    public func renameWorkspace(_ id: String, to name: String) async {
        guard let name = Self.trimmed(name) else { return }
        await run { try await self.actions.renameWorkspace(id, name) }
    }

    public func createProject(name: String, in workspaceID: String, existing: Int) async {
        guard let name = Self.trimmed(name) else { return }
        await run { try await self.actions.createProject(workspaceID, name, Self.colour(after: existing)) }
    }

    public func setStatus(_ status: String, of id: String) async {
        await run { try await self.actions.editProject(id, ProjectEdit(status: status)) }
    }

    public func rename(project id: String, to name: String) async {
        guard let name = Self.trimmed(name) else { return }
        await run { try await self.actions.editProject(id, ProjectEdit(name: name)) }
    }

    public func askToDelete(_ deletion: Deletion) { deleting = deletion }

    public func cancelDelete() { deleting = nil }

    public func confirmDelete() async {
        guard let deletion = deleting else { return }
        deleting = nil
        switch deletion {
        case .workspace(let id, _): await run { try await self.actions.deleteWorkspace(id) }
        case .project(let id, _): await run { try await self.actions.deleteProject(id) }
        }
    }

    private func run(_ work: () async throws -> Void) async {
        do {
            try await work()
            message = nil
        } catch {
            message = String(describing: error)
        }
    }

    private static func colour(after count: Int) -> String { palette[count % palette.count] }

    private static func trimmed(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
