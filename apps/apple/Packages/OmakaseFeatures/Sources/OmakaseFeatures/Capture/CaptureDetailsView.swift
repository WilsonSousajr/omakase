import SwiftUI

/// ⌘E's fields in the capture panel (glass-pass §4, #286), in G1's
/// components: the day and the estimate menu, the priority chips, the
/// notes, then the subtasks, one per line. ⏎ in a subtask line adds the
/// next line; ⏎ in the notes saves, as in the title. `onSave` closes the
/// panel around a save that happened.
///
///     CaptureDetailsView(model: model, onSave: { saved in if saved { panel.close() } })
struct CaptureDetailsView: View {
    let model: CaptureModel
    let onSave: (Bool) -> Void
    @FocusState private var focusedLine: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack(spacing: Spacing.small) {
                dayPicker
                estimateMenu
                Spacer()
            }
            PriorityChipsView(selection: Binding(get: { model.shownPriority }, set: { model.choose(priority: $0) }))
            notesField
            subtaskLines
        }
        .onChange(of: focusedLine) { model.isEditingSubtasks = focusedLine != nil }
    }

    /// Sets where ⏎ saves: the day it shows is the destination's until one is picked.
    private var dayPicker: some View {
        HStack(spacing: Spacing.tiny) {
            Image(systemName: "calendar").foregroundStyle(Palette.inkMuted.color)
            DatePicker(
                "Day", selection: Binding(get: { model.pickedDate }, set: { model.pickedDate = $0 }),
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
        }
    }

    private var estimateMenu: some View {
        Menu {
            Button("None") { model.choose(estimate: nil) }
            ForEach(CaptureModel.estimateChoices, id: \.self) { minutes in
                Button(MinutesText.format(minutes)) { model.choose(estimate: minutes) }
            }
        } label: {
            // An explicit ink label, as every menu capsule's (#172).
            Label(model.estimateTitle, systemImage: "timer").foregroundStyle(FocusPanelActionsView.menuLabel.color)
        }
        .menuStyle(.secondary)
        .fixedSize()
    }

    private var notesField: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.medium) {
            Image(systemName: "text.alignleft").foregroundStyle(Palette.inkMuted.color)
            TextField(
                "Notes", text: Binding(get: { model.details.notes }, set: { model.details.notes = $0 }),
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(1...4)
            .onSubmit { onSave(model.saveEnter()) }
        }
    }

    private var subtaskLines: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            ForEach(model.details.subtasks.indices, id: \.self) { index in subtaskLine(index) }
        }
    }

    private func subtaskLine(_ index: Int) -> some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: "circle").foregroundStyle(Palette.inkMuted.color)
            TextField(
                index == 0 ? "Subtasks, one per line" : "Subtask",
                text: Binding(get: { model.subtask(at: index) }, set: { model.setSubtask($0, at: index) })
            )
            .textFieldStyle(.plain)
            .focused($focusedLine, equals: index)
            .onSubmit { focusedLine = model.addSubtaskLine(after: index) ?? index }
        }
    }
}
