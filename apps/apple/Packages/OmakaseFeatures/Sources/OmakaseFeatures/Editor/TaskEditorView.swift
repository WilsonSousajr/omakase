import SwiftUI

/// The task editor sheet (#218): title, notes, priority, estimate and due
/// date. Save (⌘Return) hands the changes to the model; Cancel or Escape
/// closes it without writing. Monochrome: the priority dots are the only colour.
public struct TaskEditorView: View {
    @State private var model: TaskEditorModel
    @Environment(\.dismiss) private var dismiss

    public init(model: TaskEditorModel) { _model = State(initialValue: model) }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text("Edit task").sectionLabel()
            TextField("Title", text: $model.draft.title)
                .textFieldStyle(.plain)
                .font(TypeScale.title)
                .foregroundStyle(Palette.ink.color)
            TaskEditorNotesView(notes: $model.draft.notes)
            TaskEditorPriorityView(priority: $model.draft.priority)
            TaskEditorEstimateView(model: model)
            TaskEditorDueView(model: model)
            buttons
        }
        .padding(Spacing.xLarge)
        .frame(width: 440)
    }

    private var buttons: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }.buttonStyle(.glass).keyboardShortcut(.cancelAction)
            Button("Save") { if model.save() { dismiss() } }
                .buttonStyle(.primary)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!model.canSave)
                .opacity(model.canSave ? 1 : 0.4)
        }
    }
}

struct TaskEditorNotesView: View {
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Notes").sectionLabel()
            TextEditor(text: $notes)
                .font(TypeScale.body)
                .foregroundStyle(Palette.ink.color)
                .scrollContentBackground(.hidden)
                .padding(Spacing.small)
                .frame(height: 96)
                .background(Palette.surface.color, in: .rect(cornerRadius: Radius.small))
        }
    }
}

/// The four priorities as pills; the chosen one is outlined in ink.
struct TaskEditorPriorityView: View {
    @Binding var priority: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Priority").sectionLabel()
            HStack(spacing: Spacing.small) {
                ForEach(TaskDraft.priorities, id: \.self) { name in
                    Button {
                        priority = name
                    } label: {
                        pill(name)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(priority == name ? .isSelected : [])
                }
            }
        }
    }

    private func pill(_ name: String) -> some View {
        let chosen = priority == name
        return HStack(spacing: Spacing.tiny) {
            Circle().fill(PriorityMark.color(for: name).color).frame(width: 6, height: 6)
            Text(name.capitalized).font(TypeScale.caption).foregroundStyle(Palette.ink.color)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.tiny)
        .background((chosen ? Palette.surface : Palette.background).color, in: .capsule)
        .overlay(Capsule().strokeBorder((chosen ? Palette.ink : Palette.hairline).color))
        .contentShape(.capsule)
    }
}

/// Minutes, typed or stepped by 5; an empty field is no estimate.
struct TaskEditorEstimateView: View {
    @Bindable var model: TaskEditorModel

    var body: some View {
        HStack(spacing: Spacing.small) {
            Text("Estimate").sectionLabel()
            Spacer()
            TextField("None", value: $model.estimate, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
            Text("min").font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
            Stepper("Estimate", value: $model.estimateMinutes, in: 0...600, step: 5).labelsHidden()
        }
    }
}

/// A toggle for whether there is a deadline, and the day when there is.
struct TaskEditorDueView: View {
    @Bindable var model: TaskEditorModel

    var body: some View {
        HStack(spacing: Spacing.small) {
            Toggle(isOn: $model.hasDueDate) { Text("Due date").sectionLabel() }
                .toggleStyle(.switch)
                .controlSize(.small)
            Spacer()
            if model.hasDueDate {
                DatePicker("Due", selection: $model.dueDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
            }
        }
    }
}
