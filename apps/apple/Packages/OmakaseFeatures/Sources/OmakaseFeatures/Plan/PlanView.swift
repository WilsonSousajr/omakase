import SwiftUI

/// Plan (spec M4, N1): the tasks to plan from on the left, then the day or
/// week as a calendar, then, while something is selected, its panel (#217).
/// It draws values, not records. A task dragged onto a slot makes a block,
/// and a drop that overlaps asks first (#203).
///
///     PlanView(model: plan, items: blocks + classes + sessions, tasks: cards, context: context)
public struct PlanView: View {
    static let panelWidth: CGFloat = 340

    @Bindable private var model: PlanModel
    private let items: [CalendarItem]
    private let tasks: [FocusCard]
    private let context: PlanTaskContext
    /// Calendar.app's events behind the grid (#229); nil hides the toggle.
    private let overlay: CalendarOverlayModel?

    public init(
        model: PlanModel, items: [CalendarItem], tasks: [FocusCard], context: PlanTaskContext,
        overlay: CalendarOverlayModel? = nil
    ) {
        (self.model, self.items, self.tasks, self.context, self.overlay) = (model, items, tasks, context, overlay)
    }

    public var body: some View {
        HStack(spacing: 0) {
            PlanTasksColumnView(board: FocusBoard(cards: tasks), model: model).frame(width: 380)
            Divider().overlay(Palette.hairline.color)
            VStack(spacing: 0) {
                PlanHeaderView(model: model, overlay: overlay)
                Divider().overlay(Palette.hairline.color)
                CalendarGridView(model: model, items: items)
            }
            if model.selection != nil {
                Divider().overlay(Palette.hairline.color)
                PlanDetailPanelView(model: model, items: items, cards: known, context: context)
                    .frame(width: Self.panelWidth)
            }
        }
        .onChange(of: items, initial: true) { keepSelection() }
        .onChange(of: known) { keepSelection() }
        // Plan's own editor state, saved through Focus's edit action so the
        // write queues as Focus's does (#218).
        .taskEditorSheet(taskID: $model.editingID, today: context.day) { id, changes in
            context.focus.saveEdit(id, changes)
        }
        .navigationTitle("Plan")
        .confirmationDialog(model.pending?.question ?? "", isPresented: isAsking, titleVisibility: .visible) {
            Button("Place anyway") { model.confirmPending() }
            Button("Cancel", role: .cancel) { model.cancelPending() }
        }
    }

    /// Every task the panel can show: the column's and the other cached ones.
    private var known: [FocusCard] { tasks + context.cards }

    private func keepSelection() { model.keepSelection(taskIDs: Set(known.map(\.id)), items: items) }

    /// Up while an overlapping drop waits; dismissing it cancels the drop.
    private var isAsking: Binding<Bool> {
        Binding(get: { model.pending != nil }, set: { if !$0 { model.cancelPending() } })
    }
}

/// The title, the Calendar.app toggle, Today, ‹ ›, and the Day/Week switch.
struct PlanHeaderView: View {
    @Bindable var model: PlanModel
    var overlay: CalendarOverlayModel?

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Text(model.title).font(TypeScale.title).foregroundStyle(Palette.ink.color)
            Spacer()
            if let overlay { CalendarOverlayToggleView(overlay: overlay) }
            Button("Today") { model.goToday() }.buttonStyle(.secondary)
            HStack(spacing: Spacing.tiny) {
                Button("Previous", systemImage: "chevron.left") { model.previous() }
                Button("Next", systemImage: "chevron.right") { model.next() }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.icon)
            Picker("Range", selection: $model.mode) {
                Text("Day").tag(PlanModel.Mode.day)
                Text("Week").tag(PlanModel.Mode.week)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 140)
        }
        .padding(Spacing.large)
    }
}

/// The open tasks the store holds: carried over, in progress, to do. A
/// click selects one; a double-click opens it in the editor (#217, #218).
struct PlanTasksColumnView: View {
    let board: FocusBoard
    let model: PlanModel

    private var open: [FocusCard] { board.carriedOver + board.inProgress + board.toDo }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tasks").sectionLabel().padding(Spacing.large)
            Divider().overlay(Palette.hairline.color)
            if open.isEmpty {
                ContentUnavailableView("Nothing to plan", systemImage: "checkmark.circle")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        ForEach(open) { card in row(card) }
                    }
                    .padding(Spacing.large)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func row(_ card: FocusCard) -> some View {
        PlanTaskRowView(card: card, isSelected: model.selection == .task(card.id))
            .planSelectable(select: { model.select(.task(card.id)) }, edit: { model.beginEditing(card.id) })
            .draggable(PlanDragPayload.task(card.id).text)
    }
}

/// A task to plan: its kind mark, title, estimate and priority, on an
/// opaque row. No checkbox, because completing belongs to Focus. Selected,
/// it has the Kanban card's 2-pt accent border (#217). Shared with the
/// Inbox; a place's own list (S6) hides the mark, which would repeat the title.
struct PlanTaskRowView: View {
    let card: FocusCard
    var isSelected = false
    var showsKindMark = true
    @Environment(\.placeDirectory) private var directory

    var body: some View {
        HStack(spacing: Spacing.small) {
            if showsKindMark { KindMarkView(mark: directory.mark(for: card.filing)) }
            Text(card.title).font(TypeScale.body).foregroundStyle(Palette.ink.color).lineLimit(1)
            Spacer(minLength: Spacing.small)
            if card.isRepeating { RepeatGlyphView() }
            if let minutes = card.minutes, minutes > 0 {
                Text("\(minutes)m").font(TypeScale.caption).monospacedDigit().foregroundStyle(Palette.inkMuted.color)
            }
            if PriorityMark.showsInRow(card.priority) { PriorityBadgeView(priority: card.priority) }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(Palette.surface.color, in: .rect(cornerRadius: Radius.medium))
        .overlay { PlanSelectionBorderView(isSelected: isSelected, radius: Radius.medium) }
    }
}

private let previewItems = [
    CalendarItem(
        id: "c", day: "2026-09-26", start: 480, end: 570, title: "Linear algebra", kind: .classOccurrence,
        tint: Palette.indigo),
    CalendarItem(id: "b1", day: "2026-09-26", start: 540, end: 630, title: "Write the essay", kind: .block),
    CalendarItem(id: "b2", day: "2026-09-26", start: 600, end: 660, title: "Review PR", kind: .block),
    CalendarItem(id: "s", day: "2026-09-26", start: 545, end: 570, title: "Focus", kind: .focusSession),
]

#Preview("Plan, dark") {
    let focus = FocusModel(
        actions: .init(
            toggle: { _ in }, move: { _, _ in }, reschedule: { _, _ in }, toggleSubtask: { _ in },
            remind: { _, _ in }, edit: { _, _ in }))
    let context = PlanTaskContext(focus: focus, day: "2026-09-26")
    PlanView(model: PlanModel { "2026-09-26" }, items: previewItems, tasks: [], context: context)
        .frame(width: 1120, height: 680)
        .preferredColorScheme(.dark)
}
