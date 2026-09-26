import OmakaseStore
import SwiftData
import SwiftUI

/// The selected task: its dates, subtasks and actions. M3.3 puts the timer
/// above the subtasks (M3.2 decision: nothing inert ships before it).
struct FocusTaskPanelView: View {
    let card: FocusCard?
    let day: String
    let model: FocusModel

    var body: some View {
        if let card {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    Text(card.title).font(TypeScale.title).foregroundStyle(Palette.ink.color)
                    FocusMarksView(card: card, day: day, calendar: model.calendar)
                    FocusSubtasksView(taskID: card.id, model: model)
                    FocusPanelActionsView(card: card, day: day, model: model)
                }
                .padding(Spacing.large)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView("Select a task", systemImage: "scope")
        }
    }
}

/// Carried from, due, and estimate: the plan date shown apart from the deadline (#129).
struct FocusMarksView: View {
    let card: FocusCard
    let day: String
    let calendar: Calendar

    var body: some View {
        HStack(spacing: Spacing.small) {
            PriorityBadgeView(priority: card.priority)
            ForEach(FocusMarks.labels(for: card, day: day, calendar: calendar), id: \.self) { label in
                Text(label)
                    .font(TypeScale.caption)
                    .foregroundStyle((label == "Overdue" ? Palette.shu : Palette.inkMuted).color)
            }
        }
    }
}

struct FocusSubtasksView: View {
    @Query private var subtasks: [SubtaskRecord]
    private let model: FocusModel

    init(taskID: String, model: FocusModel) {
        self.model = model
        _subtasks = Query(filter: #Predicate<SubtaskRecord> { $0.taskID == taskID }, sort: \.order)
    }

    var body: some View {
        if !subtasks.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("Subtasks").sectionLabel()
                ForEach(subtasks) { subtask in
                    TaskRowView(title: subtask.title, priority: "", isCompleted: subtask.isCompleted) {
                        model.toggleSubtask(subtask.id)
                    }
                }
            }
        }
    }
}

/// Complete (the one primary action) and Reschedule.
struct FocusPanelActionsView: View {
    let card: FocusCard
    let day: String
    let model: FocusModel
    @State private var picking = false
    @State private var picked = Date.now

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Button(card.isCompleted ? "Reopen" : "Complete") { model.toggle(card.id) }
                .buttonStyle(.primary)
            Menu("Reschedule") {
                FocusRescheduleItems(card: card, day: day, model: model)
                Button("Pick a date…") { picking = true }
            }
            .menuStyle(.button)
            .buttonStyle(.glass)
            .fixedSize()
            .popover(isPresented: $picking) { datePicker }
        }
    }

    private var datePicker: some View {
        VStack(spacing: Spacing.medium) {
            DatePicker("Move to", selection: $picked, displayedComponents: .date).datePickerStyle(.graphical)
            Button("Move") {
                model.reschedule(card.id, .date(picked), today: day)
                picking = false
            }
            .buttonStyle(.primary)
        }
        .padding(Spacing.large)
    }
}

/// The reschedule choices shared by the panel's menu and the context menus.
struct FocusRescheduleItems: View {
    let card: FocusCard
    let day: String
    let model: FocusModel

    var body: some View {
        if card.isCarriedOver { Button("Move to today") { model.reschedule(card.id, .today, today: day) } }
        Button("Tomorrow") { model.reschedule(card.id, .tomorrow, today: day) }
        Button("Backlog") { model.reschedule(card.id, .backlog, today: day) }
    }
}

/// A card's or row's context menu: the panel's actions without the date picker.
struct FocusTaskMenuView: View {
    let card: FocusCard
    let day: String
    let model: FocusModel

    var body: some View {
        Button(card.isCompleted ? "Reopen" : "Complete") { model.toggle(card.id) }
        Divider()
        FocusRescheduleItems(card: card, day: day, model: model)
    }
}
