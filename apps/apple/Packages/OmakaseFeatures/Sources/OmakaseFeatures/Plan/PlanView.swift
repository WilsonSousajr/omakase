import SwiftUI

/// Plan (spec M4, N1): the tasks to plan from on the left, then the day or
/// week as a calendar. It draws values, not records. A task dragged onto a
/// slot makes a block, and a drop that overlaps asks first (#203).
///
///     PlanView(model: plan, items: blocks + classes + sessions, tasks: cards)
public struct PlanView: View {
    private let model: PlanModel
    private let items: [CalendarItem]
    private let tasks: [FocusCard]
    /// Calendar.app's events behind the grid (#229); nil hides the toggle.
    private let overlay: CalendarOverlayModel?

    public init(model: PlanModel, items: [CalendarItem], tasks: [FocusCard], overlay: CalendarOverlayModel? = nil) {
        (self.model, self.items, self.tasks, self.overlay) = (model, items, tasks, overlay)
    }

    public var body: some View {
        HStack(spacing: 0) {
            PlanTasksColumnView(board: FocusBoard(cards: tasks)).frame(width: 380)
            Divider().overlay(Palette.hairline.color)
            VStack(spacing: 0) {
                PlanHeaderView(model: model, overlay: overlay)
                Divider().overlay(Palette.hairline.color)
                CalendarGridView(model: model, items: items)
            }
        }
        .navigationTitle("Plan")
        .confirmationDialog(model.pending?.question ?? "", isPresented: isAsking, titleVisibility: .visible) {
            Button("Place anyway") { model.confirmPending() }
            Button("Cancel", role: .cancel) { model.cancelPending() }
        }
    }

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

/// The open tasks the store holds: carried over, in progress, to do.
struct PlanTasksColumnView: View {
    let board: FocusBoard

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
                            PlanTaskRowView(card: card).draggable(PlanDragPayload.task(card.id).text)
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
/// checkbox, because completing belongs to Focus.
struct PlanTaskRowView: View {
    let card: FocusCard

    var body: some View {
        HStack(spacing: Spacing.small) {
            Text(card.title).font(TypeScale.body).foregroundStyle(Palette.ink.color).lineLimit(1)
            Spacer(minLength: Spacing.small)
            if card.isRepeating { RepeatGlyphView() }
            if let minutes = card.minutes, minutes > 0 {
                Text("\(minutes)m").font(TypeScale.caption).monospacedDigit().foregroundStyle(Palette.inkMuted.color)
            }
            PriorityBadgeView(priority: card.priority)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(Palette.surface.color, in: .rect(cornerRadius: Radius.medium))
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
    PlanView(model: PlanModel { "2026-09-26" }, items: previewItems, tasks: [])
        .frame(width: 1120, height: 680)
        .preferredColorScheme(.dark)
}
