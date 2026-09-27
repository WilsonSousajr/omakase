import SwiftUI

/// Plan (spec M4, N1): the tasks to plan from on the left, then the day or
/// week as a calendar, then, while something is selected, its panel (#217).
/// It draws values, not records. A task dragged onto a slot makes a block,
/// and a drop that overlaps asks first (#203).
///
///     PlanView(model: plan, items: blocks + classes + sessions, tasks: cards, context: context)
public struct PlanView: View {
    static let panelWidth: CGFloat = 340

    private let model: PlanModel
    private let items: [CalendarItem]
    private let tasks: [FocusCard]
    private let context: PlanTaskContext

    public init(model: PlanModel, items: [CalendarItem], tasks: [FocusCard], context: PlanTaskContext) {
        (self.model, self.items, self.tasks, self.context) = (model, items, tasks, context)
    }

    public var body: some View {
        HStack(spacing: 0) {
            PlanTasksColumnView(board: FocusBoard(cards: tasks), model: model, onEdit: context.onEdit)
                .frame(width: 380)
            Divider().overlay(Palette.hairline.color)
            VStack(spacing: 0) {
                PlanHeaderView(model: model)
                Divider().overlay(Palette.hairline.color)
                CalendarGridView(model: model, items: items, onEdit: context.onEdit)
            }
            if model.selection != nil {
                Divider().overlay(Palette.hairline.color)
                PlanDetailPanelView(model: model, items: items, cards: known, context: context)
                    .frame(width: Self.panelWidth)
            }
        }
        .onChange(of: items, initial: true) { keepSelection() }
        .onChange(of: known) { keepSelection() }
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

/// The title, Today, ‹ ›, and the Day/Week switch.
struct PlanHeaderView: View {
    @Bindable var model: PlanModel

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Text(model.title).font(TypeScale.title).foregroundStyle(Palette.ink.color)
            Spacer()
            Button("Today") { model.goToday() }.buttonStyle(.glass)
            HStack(spacing: Spacing.tiny) {
                Button("Previous", systemImage: "chevron.left") { model.previous() }
                Button("Next", systemImage: "chevron.right") { model.next() }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
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
/// click selects one; a double-click asks to edit it (#217).
struct PlanTasksColumnView: View {
    let board: FocusBoard
    let model: PlanModel
    let onEdit: ((String) -> Void)?

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
                        ForEach(open) { card in
                            PlanTaskRowView(card: card, isSelected: model.selection == .task(card.id))
                                .planSelectable(select: { model.select(.task(card.id)) }, edit: { onEdit?(card.id) })
                                .draggable(PlanDragPayload.task(card.id).text)
                        }
                    }
                    .padding(Spacing.large)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// A task to plan: its title, estimate and priority, on an opaque row. No
/// checkbox, because completing belongs to Focus. Selected, it has the
/// Kanban card's 2-pt accent border (#217).
struct PlanTaskRowView: View {
    let card: FocusCard
    var isSelected = false

    var body: some View {
        HStack(spacing: Spacing.small) {
            Text(card.title).font(TypeScale.body).foregroundStyle(Palette.ink.color).lineLimit(1)
            Spacer(minLength: Spacing.small)
            if let minutes = card.minutes, minutes > 0 {
                Text("\(minutes)m").font(TypeScale.caption).monospacedDigit().foregroundStyle(Palette.inkMuted.color)
            }
            PriorityBadgeView(priority: card.priority)
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
            remind: { _, _ in }))
    PlanView(
        model: PlanModel { "2026-09-26" }, items: previewItems, tasks: [],
        context: PlanTaskContext(focus: focus, day: "2026-09-26"))
        .frame(width: 1120, height: 680)
        .preferredColorScheme(.dark)
}
