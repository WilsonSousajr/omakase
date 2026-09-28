import OmakaseStore
import SwiftData
import SwiftUI

/// Projects (#226): workspaces on the left (All first), their projects as
/// cards on the right. Every write is online; a failure is said at the foot.
/// A card opens its own task list (spec §6): double-click, ⏎ on a selected
/// one, or the context menu's Open, all through `open`.
public struct ProjectsView: View {
    @Bindable private var model: ProjectsModel
    private let open: (TaskPlace) -> Void
    @Query(sort: \WorkspaceRecord.name) private var workspaces: [WorkspaceRecord]
    @Query(sort: \ProjectRecord.name) private var projects: [ProjectRecord]
    @State private var naming: ProjectsNaming?

    public init(model: ProjectsModel, open: @escaping (TaskPlace) -> Void) {
        (self.model, self.open) = (model, open)
    }

    public var body: some View {
        HStack(spacing: 0) {
            ProjectsWorkspaceList(model: model, workspaces: workspaces, naming: $naming).frame(width: 220)
            Divider().overlay(Palette.hairline.color)
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().overlay(Palette.hairline.color)
                ProjectsGrid(
                    model: model, cards: model.visible(projects.map(ProjectCard.init(record:))), naming: $naming,
                    open: open)
                if let message = model.message {
                    Text(message).font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color).padding(
                        Spacing.medium)
                }
            }
        }
        .projectsNamingAlert($naming, model: model, workspaceCount: workspaces.count, projectCount: projects.count)
        .confirmationDialog(
            "Delete this?", isPresented: deleting, titleVisibility: .visible,
            actions: {
                Button("Delete", role: .destructive) { Task { await model.confirmDelete() } }
                Button("Cancel", role: .cancel) { model.cancelDelete() }
            },
            message: { Text(model.deleting?.warning ?? "") })
    }

    private var header: some View {
        HStack {
            Text(workspaces.first { $0.id == model.selectedWorkspaceID }?.name ?? "All projects").sectionLabel()
            Spacer()
            Button("New Project…") { naming = .newProject(workspaceID: newProjectWorkspace ?? "") }
                .buttonStyle(.secondary)
                .disabled(newProjectWorkspace == nil)
                .help(newProjectWorkspace == nil ? "Create a workspace first" : "")
        }
        .padding(.horizontal, Spacing.large).padding(.vertical, Spacing.medium)
    }

    /// The selected workspace, or the only one when All is selected.
    private var newProjectWorkspace: String? {
        model.selectedWorkspaceID ?? (workspaces.count == 1 ? workspaces.first?.id : nil)
    }

    private var deleting: Binding<Bool> {
        Binding(get: { model.deleting != nil }, set: { if !$0 { model.cancelDelete() } })
    }
}

/// What the name alert is naming.
enum ProjectsNaming: Identifiable, Equatable {
    case newWorkspace
    case renameWorkspace(id: String, name: String)
    case newProject(workspaceID: String)
    case renameProject(id: String, name: String)

    var id: String { String(describing: self) }

    var title: String {
        switch self {
        case .newWorkspace: "New workspace"
        case .renameWorkspace: "Rename workspace"
        case .newProject: "New project"
        case .renameProject: "Rename project"
        }
    }

    var initialName: String {
        switch self {
        case .renameWorkspace(_, let name), .renameProject(_, let name): name
        case .newWorkspace, .newProject: ""
        }
    }
}

struct ProjectsWorkspaceList: View {
    @Bindable var model: ProjectsModel
    let workspaces: [WorkspaceRecord]
    @Binding var naming: ProjectsNaming?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: $model.selectedWorkspaceID) {
                Label("All", systemImage: "square.grid.2x2").tag(String?.none)
                ForEach(workspaces) { workspace in
                    Label(workspace.name, systemImage: "circle.fill")
                        .foregroundStyle(Palette.ink.color)
                        .tint(DesignColor(hex: workspace.color)?.color ?? Palette.accent.color)
                        .tag(Optional(workspace.id))
                        .contextMenu { menu(workspace) }
                }
            }
            .scrollContentBackground(.hidden)
            Button("New Workspace…") { naming = .newWorkspace }.buttonStyle(.secondary).padding(Spacing.medium)
        }
    }

    @ViewBuilder private func menu(_ workspace: WorkspaceRecord) -> some View {
        Button("Rename…") { naming = .renameWorkspace(id: workspace.id, name: workspace.name) }
        Button("Delete…", role: .destructive) {
            model.askToDelete(.workspace(id: workspace.id, name: workspace.name))
        }
    }
}

struct ProjectsGrid: View {
    let model: ProjectsModel
    let cards: [ProjectCard]
    @Binding var naming: ProjectsNaming?
    let open: (TaskPlace) -> Void

    var body: some View {
        ScrollView {
            if cards.isEmpty {
                Text("No projects here yet.").font(TypeScale.body).foregroundStyle(Palette.inkMuted.color)
                    .padding(Spacing.large)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: Spacing.medium)], spacing: Spacing.medium) {
                ForEach(cards) { card in row(card) }
            }
            .padding(Spacing.large)
        }
        .background(openShortcut)
    }

    private func row(_ card: ProjectCard) -> some View {
        ProjectCardView(card: card, isSelected: model.selectedID == card.id)
            .onTapGesture { model.selectedID = card.id }
            // Simultaneous, so a single click still selects at once (spec §6, matches Focus's board, #218).
            .simultaneousGesture(TapGesture(count: 2).onEnded { open(card.place) })
            .contextMenu { menu(card) }
    }

    /// ⏎ opens the selected card's list, the same place the double-click and
    /// the context menu's Open do (spec §6). Invisible: it carries no
    /// control of its own, only the shortcut.
    private var openShortcut: some View {
        Button("Open", action: openSelected).keyboardShortcut(.return, modifiers: [])
            .disabled(model.selectedID == nil)
            .hidden()
    }

    private func openSelected() { model.selectedPlace(in: cards).map(open) }

    @ViewBuilder private func menu(_ card: ProjectCard) -> some View {
        Button("Open") { open(card.place) }
        Button("Rename…") { naming = .renameProject(id: card.id, name: card.name) }
        Menu("Status") {
            ForEach(ProjectsModel.statuses, id: \.self) { status in
                Button(status.capitalized) { Task { await model.setStatus(status, of: card.id) } }
            }
        }
        Button("Delete…", role: .destructive) { model.askToDelete(.project(id: card.id, name: card.name)) }
    }
}

/// A project: its colour as a bar, its name, status and task count. A
/// selected card (spec §6) is outlined; ⏎ and Open act on it.
struct ProjectCardView: View {
    let card: ProjectCard
    var isSelected = false

    var body: some View {
        HStack(spacing: Spacing.small) {
            Capsule().fill(DesignColor(hex: card.color)?.color ?? Palette.accent.color).frame(width: 3)
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                Text(card.name).font(TypeScale.headline).foregroundStyle(Palette.ink.color).lineLimit(1)
                Text("\(card.status.capitalized) · \(card.taskCount) \(card.taskCount == 1 ? "task" : "tasks")")
                    .font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface.color, in: .rect(cornerRadius: Radius.medium))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: Radius.medium).strokeBorder(Palette.accent.color, lineWidth: 2)
            }
        }
        .contentShape(.rect(cornerRadius: Radius.medium))
    }
}

extension View {
    /// The one text-field alert Projects uses to name and rename.
    func projectsNamingAlert(
        _ naming: Binding<ProjectsNaming?>, model: ProjectsModel, workspaceCount: Int, projectCount: Int
    ) -> some View {
        modifier(ProjectsNamingAlert(naming: naming, model: model, counts: (workspaceCount, projectCount)))
    }
}

struct ProjectsNamingAlert: ViewModifier {
    @Binding var naming: ProjectsNaming?
    let model: ProjectsModel
    let counts: (workspaces: Int, projects: Int)
    @State private var text = ""

    func body(content: Content) -> some View {
        content
            .alert(naming?.title ?? "", isPresented: isPresented) {
                TextField("Name", text: $text)
                Button("Save") { save() }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: naming) { _, value in text = value?.initialName ?? "" }
    }

    private var isPresented: Binding<Bool> { Binding(get: { naming != nil }, set: { if !$0 { naming = nil } }) }

    private func save() {
        guard let naming else { return }
        let name = text
        Task {
            switch naming {
            case .newWorkspace: await model.createWorkspace(name: name, existing: counts.workspaces)
            case .renameWorkspace(let id, _): await model.renameWorkspace(id, to: name)
            case .newProject(let workspace):
                await model.createProject(name: name, in: workspace, existing: counts.projects)
            case .renameProject(let id, _): await model.rename(project: id, to: name)
            }
        }
    }
}
