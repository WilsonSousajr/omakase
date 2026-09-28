import Foundation
import OmakaseFeatures
import OmakaseStore
import SwiftData

extension AppServices {
    /// Projects' writes (#226): online, through ProjectWrites; a record gone
    /// from the cache meanwhile is a no-op.
    func projectsActions() -> ProjectsModel.Actions {
        let writes = ProjectWrites(api: api, context: container.mainContext)
        return ProjectsModel.Actions(
            createWorkspace: { name, color in _ = try await writes.createWorkspace(name: name, color: color) },
            renameWorkspace: { [self] id, name in
                if let workspace = workspace(id) { try await writes.renameWorkspace(workspace, to: name) }
            },
            deleteWorkspace: { [self] id in
                if let workspace = workspace(id) { try await writes.deleteWorkspace(workspace) }
            },
            createProject: { [self] workspaceID, name, color in
                guard let workspace = workspace(workspaceID) else { return }
                _ = try await writes.createProject(in: workspace, name: name, color: color)
            },
            editProject: { [self] id, edit in
                if let project = project(id) { try await writes.editProject(project, edit) }
            },
            deleteProject: { [self] id in if let project = project(id) { try await writes.deleteProject(project) } })
    }

    private func workspace(_ id: String) -> WorkspaceRecord? {
        try? container.mainContext.fetch(FetchDescriptor<WorkspaceRecord>(predicate: #Predicate { $0.id == id })).first
    }

    private func project(_ id: String) -> ProjectRecord? {
        try? container.mainContext.fetch(FetchDescriptor<ProjectRecord>(predicate: #Predicate { $0.id == id })).first
    }
}
