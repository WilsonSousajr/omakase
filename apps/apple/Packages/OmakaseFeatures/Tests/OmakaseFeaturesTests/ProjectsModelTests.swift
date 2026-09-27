import Foundation
import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// Projects (#226): workspaces and their projects, written online. A
/// failure is said at the foot; a delete asks first, saying what goes.
@MainActor
struct ProjectsModelTests {
    final class Recorder {
        var calls: [String] = []
        var failure: Error?
    }

    struct Offline: Error, CustomStringConvertible { var description: String { "Needs a connection." } }

    private let recorder = Recorder()

    private func model() -> ProjectsModel {
        let recorder = recorder
        func record(_ call: String) throws {
            if let failure = recorder.failure { throw failure }
            recorder.calls.append(call)
        }
        return ProjectsModel(
            actions: .init(
                createWorkspace: { name, color in try record("workspace \(name) \(color)") },
                renameWorkspace: { id, name in try record("rename \(id) \(name)") },
                deleteWorkspace: { id in try record("delete workspace \(id)") },
                createProject: { workspace, name, color in try record("project \(workspace) \(name) \(color)") },
                editProject: { id, edit in try record("edit \(id) \(edit.status ?? "-")") },
                deleteProject: { id in try record("delete project \(id)") }))
    }

    private let cards = [
        ProjectCard(id: "p1", workspaceID: "w1", name: "Thesis", color: "#3b82f6", status: "active", taskCount: 3),
        ProjectCard(id: "p2", workspaceID: "w2", name: "Site", color: "#22c55e", status: "paused", taskCount: 0),
    ]

    @Test func allShowsEveryProjectAndAWorkspaceShowsItsOwn() {
        let projects = model()
        #expect(projects.visible(cards).map(\.id) == ["p1", "p2"])
        projects.selectedWorkspaceID = "w2"
        #expect(projects.visible(cards).map(\.id) == ["p2"])
    }

    @Test func aNewWorkspaceTakesTheNextColourAndATrimmedName() async {
        await model().createWorkspace(name: "  Clients  ", existing: 1)
        #expect(recorder.calls == ["workspace Clients \(ProjectsModel.palette[1])"])
    }

    @Test func aBlankNameCreatesNothing() async {
        let projects = model()
        await projects.createWorkspace(name: "   ", existing: 0)
        await projects.createProject(name: "", in: "w1", existing: 0)
        #expect(recorder.calls.isEmpty)
    }

    @Test func aProjectIsCreatedInTheChosenWorkspace() async {
        await model().createProject(name: "Thesis", in: "w1", existing: 2)
        #expect(recorder.calls == ["project w1 Thesis \(ProjectsModel.palette[2])"])
    }

    @Test func aStatusChangeIsAnEdit() async {
        await model().setStatus("paused", of: "p1")
        #expect(recorder.calls == ["edit p1 paused"])
    }

    @Test func aFailureIsSaidAndClearedByTheNextSuccess() async {
        let projects = model()
        recorder.failure = Offline()
        await projects.setStatus("paused", of: "p1")
        #expect(projects.message == "Needs a connection.")
        recorder.failure = nil
        await projects.setStatus("active", of: "p1")
        #expect(projects.message == nil)
    }

    @Test func deletingAWorkspaceAsksFirstAndSaysItsProjectsGo() async {
        let projects = model()
        projects.askToDelete(.workspace(id: "w1", name: "Clients"))
        #expect(projects.deleting?.warning == "Its projects go too. Their tasks stay, without a project.")
        #expect(recorder.calls.isEmpty)
        await projects.confirmDelete()
        #expect(recorder.calls == ["delete workspace w1"] && projects.deleting == nil)
    }

    @Test func deletingAProjectKeepsItsTasks() async {
        let projects = model()
        projects.askToDelete(.project(id: "p1", name: "Thesis"))
        #expect(projects.deleting?.warning == "Its tasks stay, without a project.")
        projects.cancelDelete()
        await projects.confirmDelete()
        #expect(recorder.calls.isEmpty)
    }
}
