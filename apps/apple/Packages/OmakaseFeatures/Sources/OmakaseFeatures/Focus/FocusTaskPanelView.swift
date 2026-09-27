import OmakaseStore
import SwiftData
import SwiftUI

/// The selected task: its dates, the pomodoro timer (M3.3), its subtasks
/// and actions.
struct FocusTaskPanelView: View {
    let card: FocusCard?
    let day: String
    let model: FocusModel
    let timer: TimerModel

    var body: some View {
        if let card {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    Text(card.title).font(TypeScale.title).foregroundStyle(Palette.ink.color)
                    FocusMarksView(card: card, day: day, calendar: model.calendar)
                    FocusTimerView(timer: timer, taskID: card.id)
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

/// Complete (the one primary action) and Edit…, then Reschedule and Remind
/// me, then Repeat (#206). Rows of two: more overflow the 340-point panel.
struct FocusPanelActionsView: View {
    /// The Reschedule menu's label: ink, like the other glass buttons. Left to
    /// itself a `.menuStyle(.button)` menu draws it dim, as if disabled (#172).
    static let menuLabel = Palette.ink
    let card: FocusCard
    let day: String
    let model: FocusModel
    /// Where Edit… goes instead of Focus's own editor: Plan opens the
    /// editor from its model (#217). Nil in Focus.
    var edit: ((String) -> Void)?
    @State private var picking = false
    @State private var picked = Date.now

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack(spacing: Spacing.medium) {
                Button(card.isCompleted ? "Reopen" : "Complete") { model.toggle(card.id) }
                    .buttonStyle(.primary)
                editButton
            }
            HStack(spacing: Spacing.medium) {
                rescheduleMenu
                FocusRemindMenuView(card: card, model: model)
            }
            FocusRepeatMenuView(card: card, day: day, model: model)
        }
    }

    /// Return opens it too (#218): the panel shows only while a task is selected.
    private var editButton: some View {
        Button {
            if let edit { edit(card.id) } else { model.beginEditing(card.id) }
        } label: {
            Text("Edit…").foregroundStyle(Self.menuLabel.color)
        }
        .buttonStyle(.glass)
        .keyboardShortcut(.return, modifiers: [])
    }

    private var rescheduleMenu: some View {
        Menu {
            FocusRescheduleItems(card: card, day: day, model: model)
            Button("Pick a date…") { picking = true }
        } label: {
            Text("Reschedule").foregroundStyle(Self.menuLabel.color)
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .fixedSize()
        .popover(isPresented: $picking) { datePicker }
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

/// "Remind me" (#187): the presets on offer now, a picked time, or clear.
/// Its label is ink, as Reschedule's is (#172).
struct FocusRemindMenuView: View {
    let card: FocusCard
    let model: FocusModel
    @State private var picking = false
    @State private var picked = Date.now

    var body: some View {
        Menu {
            ForEach(ReminderChoice.presets(now: .now, calendar: model.calendar), id: \.title) { choice in
                Button(choice.title) { model.remind(card.id, choice) }
            }
            Button(ReminderChoice.picked(.now).title) { picking = true }
            if card.hasReminder { Button(ReminderChoice.clear.title) { model.remind(card.id, .clear) } }
        } label: {
            Text("Remind me").foregroundStyle(FocusPanelActionsView.menuLabel.color)
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .fixedSize()
        .popover(isPresented: $picking) { timePicker }
    }

    private var timePicker: some View {
        VStack(spacing: Spacing.medium) {
            DatePicker("Remind at", selection: $picked, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
            Button("Remind me") {
                model.remind(card.id, .picked(picked))
                picking = false
            }
            .buttonStyle(.primary)
        }
        .padding(Spacing.large)
    }
}

/// "Repeat" (#206): a rule from the task's day, or Stop repeating for a task
/// in a series. Its label is ink, as Reschedule's is (#172).
struct FocusRepeatMenuView: View {
    let card: FocusCard
    let day: String
    let model: FocusModel

    var body: some View {
        Menu {
            let choices = RepeatChoice.choices(
                for: card.scheduledDay ?? day, isRepeating: card.isRepeating, calendar: model.calendar)
            ForEach(choices, id: \.self) { choice in
                Button(choice.title(calendar: model.calendar)) { model.setRepeat(card, choice, today: day) }
            }
        } label: {
            Label("Repeat", systemImage: "repeat").foregroundStyle(FocusPanelActionsView.menuLabel.color)
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .fixedSize()
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
        Button("Edit…") { model.beginEditing(card.id) }
        Divider()
        FocusRescheduleItems(card: card, day: day, model: model)
    }
}
