import OmakaseStore
import SwiftData
import SwiftUI

/// The Inbox (#225): every open task with no day, newest first. Each row is
/// given a day, done, edited or deleted; nothing here is scheduled for you.
public struct InboxView: View {
    private let day: String
    @Bindable private var model: TriageModel
    @Query(
        filter: #Predicate<TaskRecord> { $0.scheduledDay == nil && !$0.isCompleted },
        sort: \TaskRecord.updatedAt, order: .reverse)
    private var tasks: [TaskRecord]

    public init(day: String, model: TriageModel) { (self.day, self.model) = (day, model) }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Inbox · \(tasks.count)").sectionLabel()
                .padding(.horizontal, Spacing.large).padding(.vertical, Spacing.medium)
            Divider().overlay(Palette.hairline.color)
            if tasks.isEmpty { InboxEmptyView() } else { list }
        }
        .taskEditorSheet(taskID: $model.editingID, today: day) { id, changes in model.saveEdit(id, changes) }
        .confirmationDialog(
            "Delete this task?", isPresented: deleting, titleVisibility: .visible,
            actions: {
                Button("Delete", role: .destructive) { model.confirmDelete() }
                Button("Cancel", role: .cancel) { model.cancelDelete() }
            },
            message: { Text("It goes from every device once the server hears of it.") })
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.small) {
                ForEach(tasks) { task in TriageRowView(card: FocusCard(record: task), model: model) }
            }
            .padding(Spacing.large)
        }
    }

    private var deleting: Binding<Bool> {
        Binding(get: { model.deletingID != nil }, set: { if !$0 { model.cancelDelete() } })
    }
}

/// One task: the row itself, a "Today" shortcut, and the rest in a menu.
/// Shared by the Inbox and a place's list (spec §5), so both triage a task
/// the same way. A place's own list hides the kind mark (spec §8), which
/// would only repeat the place's own title.
struct TriageRowView: View {
    let card: FocusCard
    let model: TriageModel
    var showsKindMark = true
    @State private var picking = false
    @State private var picked = Date.now

    var body: some View {
        HStack(spacing: Spacing.small) {
            PlanTaskRowView(card: card, showsKindMark: showsKindMark)
            Button("Today") { model.schedule(card.id, .today) }.buttonStyle(.glass)
            Menu {
                TriageActionItems(card: card, model: model) { picking = true }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(Palette.ink.color)
            }
            .menuStyle(.button)
            .buttonStyle(.glass)
            .fixedSize()
            .popover(isPresented: $picking) { datePicker }
        }
        .contentShape(.rect)
        .onTapGesture(count: 2) { model.beginEditing(card.id) }
        .contextMenu { TriageActionItems(card: card, model: model) { picking = true } }
    }

    private var datePicker: some View {
        VStack(spacing: Spacing.medium) {
            DatePicker("Move to", selection: $picked, displayedComponents: .date).datePickerStyle(.graphical)
            Button("Move") {
                model.schedule(card.id, .date(picked))
                picking = false
            }
            .buttonStyle(.primary)
        }
        .padding(Spacing.large)
    }
}

/// The row's menu and context menu: the same choices in the same order.
struct TriageActionItems: View {
    let card: FocusCard
    let model: TriageModel
    let pickDate: () -> Void

    var body: some View {
        Button("Today") { model.schedule(card.id, .today) }
        Button("Tomorrow") { model.schedule(card.id, .tomorrow) }
        Button("Pick a date…") { pickDate() }
        Divider()
        Button("Edit…") { model.beginEditing(card.id) }
        Button("Complete") { model.complete(card.id) }
        Divider()
        Button("Delete…", role: .destructive) { model.askToDelete(card.id) }
    }
}

/// Nothing to triage, and how things arrive here.
struct InboxEmptyView: View {
    var body: some View {
        VStack(spacing: Spacing.small) {
            Image(systemName: "tray").font(.largeTitle).foregroundStyle(Palette.inkMuted.color)
            Text("Nothing to triage").font(TypeScale.headline).foregroundStyle(Palette.ink.color)
            Text("⌥⌘N, then ⌘⏎, puts a task here.").font(TypeScale.caption).foregroundStyle(
                Palette.inkMuted.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
