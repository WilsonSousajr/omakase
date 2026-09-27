import SwiftUI

/// What Plan's panel needs to show a task (#217): Focus's model, whose
/// injected actions complete, reschedule, remind and save edits (#218); the
/// day its marks, reschedules and editor count from; and every cached task,
/// so a block's parent opens although it is not in the column.
///
///     PlanTaskContext(focus: focus, day: day, cards: all)
public struct PlanTaskContext {
    let focus: FocusModel
    let day: String
    let cards: [FocusCard]

    public init(focus: FocusModel, day: String, cards: [FocusCard] = []) {
        (self.focus, self.day, self.cards) = (focus, day, cards)
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
            PlanBlockDetailView(block: block, model: model) { model.editSelected(in: items) }
        } else if case .task(let id) = model.selection, let card = cards.first(where: { $0.id == id }) {
            PlanTaskDetailView(card: card, model: model, context: context)
        }
    }
}

/// A task in Plan: Focus's panel without the timer, which belongs to doing,
/// not placing. The pieces are Focus's own views, so both panels act alike;
/// only Edit… (Return) opens Plan's editor instead of Focus's (#218).
struct PlanTaskDetailView: View {
    let card: FocusCard
    let model: PlanModel
    let context: PlanTaskContext

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text(card.title).font(TypeScale.title).foregroundStyle(Palette.ink.color)
            FocusMarksView(card: card, day: context.day, calendar: context.focus.calendar)
            FocusSubtasksView(taskID: card.id, model: context.focus)
            FocusPanelActionsView(
                card: card, day: context.day, model: context.focus, edit: { model.beginEditing($0) })
        }
    }
}

/// A block in Plan: its parent's title, day and times; Open task and Edit
/// task… (Return) when the parent is a task; and Delete block. Two rows,
/// as in Focus's panel: three buttons overflow it.
struct PlanBlockDetailView: View {
    let block: CalendarItem
    let model: PlanModel
    let edit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text(block.title).font(TypeScale.title).foregroundStyle(Palette.ink.color)
            Text("\(model.dayHeader(block.day)) · \(block.timeRange)")
                .font(TypeScale.body).monospacedDigit()
                .foregroundStyle(Palette.inkMuted.color)
            if block.taskID != nil {
                HStack(spacing: Spacing.medium) {
                    Button("Open task") { model.openTask(of: block) }.buttonStyle(.glass)
                    Button("Edit task…", action: edit).buttonStyle(.glass).keyboardShortcut(.return, modifiers: [])
                }
            }
            Button("Delete block", role: .destructive) { model.deleteBlock(block.id) }.buttonStyle(.glass)
        }
    }
}
