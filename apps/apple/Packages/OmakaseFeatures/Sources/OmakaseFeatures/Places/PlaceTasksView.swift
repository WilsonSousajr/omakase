import OmakaseStore
import SwiftData
import SwiftUI

/// A place's open tasks (spec §5): a project's, a discipline's, or Life's,
/// grouped Overdue/Today/Upcoming/No date. Rows and their ⋯ actions are
/// `TriageRowView`'s, the same ones the Inbox uses, because a place list
/// triages exactly the way the Inbox does — apart from the kind mark
/// (spec §8), which is hidden here, since it would only repeat this
/// screen's own title.
public struct PlaceTasksView: View {
    private let place: TaskPlace
    private let day: String
    private let model: PlaceListModel
    @Bindable private var triage: TriageModel
    @Environment(\.placeDirectory) private var directory
    @Query private var tasks: [TaskRecord]

    public init(place: TaskPlace, day: String, model: PlaceListModel, triage: TriageModel) {
        (self.place, self.day, self.model, self.triage) = (place, day, model, triage)
        _tasks = Query(filter: place.openTasksPredicate, sort: \TaskRecord.updatedAt, order: .reverse)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).sectionLabel().padding(.horizontal, Spacing.large).padding(.vertical, Spacing.medium)
            Divider().overlay(Palette.hairline.color)
            if tasks.isEmpty { PlaceTasksEmptyView(name: title) } else { list }
        }
        .taskEditorSheet(taskID: $triage.editingID, today: day) { id, changes in triage.saveEdit(id, changes) }
        .confirmationDialog(
            "Delete this task?", isPresented: deleting, titleVisibility: .visible,
            actions: {
                Button("Delete", role: .destructive) { triage.confirmDelete() }
                Button("Cancel", role: .cancel) { triage.cancelDelete() }
            },
            message: { Text("It goes from every device once the server hears of it.") }
        )
        .onAppear { model.show(place) }
        .onChange(of: place) { _, newPlace in model.show(newPlace) }
        .onDisappear { model.hide() }
    }

    private var title: String { directory.mark(for: place.filing).title }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.medium) {
                ForEach(sections) { group in PlaceSectionView(group: group, model: triage) }
            }
            .padding(Spacing.large)
        }
    }

    private var sections: [PlaceTaskGroup] {
        PlaceSections.group(tasks.map(FocusCard.init(record:)), today: day)
    }

    private var deleting: Binding<Bool> {
        Binding(get: { triage.deletingID != nil }, set: { if !$0 { triage.cancelDelete() } })
    }
}

/// One section's label and its rows.
struct PlaceSectionView: View {
    let group: PlaceTaskGroup
    let model: TriageModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(group.section.title).sectionLabel()
            ForEach(group.cards) { card in TriageRowView(card: card, model: model, showsKindMark: false) }
        }
    }
}

/// Nothing open here yet, and how to add one.
struct PlaceTasksEmptyView: View {
    let name: String

    var body: some View {
        VStack(spacing: Spacing.small) {
            Image(systemName: "tray").font(.largeTitle).foregroundStyle(Palette.inkMuted.color)
            Text("Nothing here yet").font(TypeScale.headline).foregroundStyle(Palette.ink.color)
            Text("⌘N adds a task to \(name).").font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
