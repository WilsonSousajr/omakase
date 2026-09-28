import OmakaseStore
import SwiftUI

/// The parent menu chip (spec §4): the current kind's places, grouped by
/// workspace, plus "None". Shared by capture and the task editor (S5,
/// #258), so re-filing looks and works the same everywhere. Hidden for
/// Life, and whenever the kind has no places to offer (an empty library
/// cache).
///
///     ParentMenuChip(area: model.area, parent: Binding(get: { model.parent }, set: { model.choose(parent: $0) }),
///                    directory: model.directory)
public struct ParentMenuChip: View {
    /// A long project or discipline name is truncated instead of pushing
    /// the kind chips out of the row (#264's review).
    private static let maxLabelWidth: CGFloat = 200

    private let area: TaskArea
    @Binding private var parent: TaskParent?
    private let directory: PlaceDirectory

    public init(area: TaskArea, parent: Binding<TaskParent?>, directory: PlaceDirectory) {
        self.area = area
        _parent = parent
        self.directory = directory
    }

    public var body: some View {
        if !choices.isEmpty { menu }
    }

    private var choices: [PlaceEntry] { directory.places(for: area) }

    /// The parent's name, or which kind of parent is missing.
    private var title: String {
        guard let parent else { return area == .study ? "No discipline" : "No project" }
        return directory.mark(for: TaskFiling(area: area, parent: parent)).title
    }

    private var menu: some View {
        Menu {
            Button("None") { parent = nil }
            ForEach(PlaceGroup.groups(of: choices)) { group in section(group) }
        } label: {
            // An explicit ink label, as every menu capsule's (#172).
            Text(title).foregroundStyle(FocusPanelActionsView.menuLabel.color).lineLimit(1).truncationMode(.tail)
        }
        .menuStyle(.secondary)
        .frame(maxWidth: Self.maxLabelWidth, alignment: .trailing)
    }

    @ViewBuilder private func section(_ group: PlaceGroup) -> some View {
        if let title = group.title {
            Section(title) { buttons(group.entries) }
        } else {
            Section { buttons(group.entries) }
        }
    }

    private func buttons(_ entries: [PlaceEntry]) -> some View {
        ForEach(entries) { entry in
            Button(entry.title) { parent = entry.parent }
        }
    }
}

#Preview("Parent menu chip") {
    @Previewable @State var parent: TaskParent? = .project("p1")
    let directory = PlaceDirectory(
        projects: [
            PlaceEntry(
                parent: .project("p1"), title: "A fifty character project name for width testing",
                group: nil, color: KindTint.work)
        ], disciplines: [], semesterTitle: nil)
    ParentMenuChip(area: .work, parent: $parent, directory: directory).padding(Spacing.large)
}
