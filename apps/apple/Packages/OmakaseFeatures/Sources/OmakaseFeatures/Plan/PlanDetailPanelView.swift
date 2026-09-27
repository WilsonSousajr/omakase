import SwiftUI

/// What Plan's panel needs to show a task (#217): Focus's model, whose
/// injected actions complete, reschedule and remind; the day its marks and
/// reschedules count from; every cached task, so a block's parent opens
/// although it is not in the column; and the edit hook.
///
/// `onEdit` is the task editor's entry point (#218). While it is nil,
/// double-click does nothing and the panel has no Edit button; once the
/// app passes it, double-clicking a task row or block, or Edit (Return) in
/// the panel, calls it with the task's id.
///
///     PlanTaskContext(focus: focus, day: day, cards: all, onEdit: { editor.open($0) })
public struct PlanTaskContext {
    let focus: FocusModel
    let day: String
    let cards: [FocusCard]
    let onEdit: ((String) -> Void)?

    public init(focus: FocusModel, day: String, cards: [FocusCard] = [], onEdit: ((String) -> Void)? = nil) {
        (self.focus, self.day, self.cards, self.onEdit) = (focus, day, cards, onEdit)
    }
}

/// Plan's right-hand panel, like Focus's third column: the selected task,
/// or the selected block with its time, Open task and Delete (#217).
struct PlanDetailPanelView: View {
    let model: PlanModel
    let items: [CalendarItem]
    let cards: [FocusCard]
    let context: PlanTaskContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(model.selectedBlock(in: items) == nil ? "Task" : "Block").sectionLabel()
                Spacer()
                Button("Close", systemImage: "xmark") { model.select(nil) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.inkMuted.color)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(Spacing.large)
            Divider().overlay(Palette.hairline.color)
            ScrollView {
                content.padding(Spacing.large).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private var content: some View {
        if let block = model.selectedBlock(in: items) {
            PlanBlockDetailView(block: block, model: model)
        } else if case .task(let id) = model.selection, let card = cards.first(where: { $0.id == id }) {
            PlanTaskDetailView(card: card, context: context)
        }
    }
}

/// A task in Plan: Focus's panel without the timer, which belongs to doing,
/// not placing. The pieces are Focus's own views, so both panels act alike.
struct PlanTaskDetailView: View {
    let card: FocusCard
    let context: PlanTaskContext

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text(card.title).font(TypeScale.title).foregroundStyle(Palette.ink.color)
            FocusMarksView(card: card, day: context.day, calendar: context.focus.calendar)
            FocusSubtasksView(taskID: card.id, model: context.focus)
            FocusPanelActionsView(card: card, day: context.day, model: context.focus)
            if let onEdit = context.onEdit {
                Button("Edit task…") { onEdit(card.id) }
                    .buttonStyle(.glass)
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
    }
}

/// A block in Plan: its parent's title, day and times, Open task (when the
/// parent is a task) and Delete block.
struct PlanBlockDetailView: View {
    let block: CalendarItem
    let model: PlanModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text(block.title).font(TypeScale.title).foregroundStyle(Palette.ink.color)
            Text("\(model.dayHeader(block.day)) · \(block.timeRange)")
                .font(TypeScale.body).monospacedDigit()
                .foregroundStyle(Palette.inkMuted.color)
            HStack(spacing: Spacing.medium) {
                if block.taskID != nil {
                    Button("Open task") { model.openTask(of: block) }.buttonStyle(.glass)
                }
                Button("Delete block", role: .destructive) { model.deleteBlock(block.id) }.buttonStyle(.glass)
            }
        }
    }
}
