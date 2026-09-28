import OmakaseStore
import SwiftData
import SwiftUI

extension View {
    /// Presents the task editor (#218) while `taskID` is set, and clears it
    /// on close. Any screen that shows tasks opens the same editor with it:
    /// Focus today, Plan next (#217).
    ///
    ///     .taskEditorSheet(taskID: $model.editingID, today: day) { id, changes in model.saveEdit(id, changes) }
    public func taskEditorSheet(
        taskID: Binding<String?>, today: String, save: @escaping (String, TaskEdit) -> Void
    ) -> some View {
        let isPresented = Binding(
            get: { taskID.wrappedValue != nil },
            set: { presented in if !presented { taskID.wrappedValue = nil } })
        return sheet(isPresented: isPresented) {
            if let id = taskID.wrappedValue { TaskEditorSheetView(taskID: id, today: today, save: save) }
        }
    }
}

/// Reads the task from the store and opens the editor on its current values.
struct TaskEditorSheetView: View {
    @Query private var records: [TaskRecord]
    private let taskID: String
    private let today: String
    private let save: (String, TaskEdit) -> Void
    @Environment(\.dismiss) private var dismiss

    init(taskID: String, today: String, save: @escaping (String, TaskEdit) -> Void) {
        (self.taskID, self.today, self.save) = (taskID, today, save)
        _records = Query(filter: #Predicate<TaskRecord> { $0.id == taskID })
    }

    var body: some View {
        if let record = records.first {
            let (taskID, save) = (taskID, save)
            TaskEditorView(
                model: TaskEditorModel(
                    draft: TaskDraft(record: record), today: today, actions: .init { save(taskID, $0) }))
        } else {
            // Deleted elsewhere while the sheet was opening: say so, and let Escape close it.
            VStack(spacing: Spacing.large) {
                ContentUnavailableView("This task is no longer here", systemImage: "questionmark.circle")
                Button("Close") { dismiss() }.buttonStyle(.secondary).keyboardShortcut(.cancelAction)
            }
            .padding(Spacing.xLarge)
            .frame(width: 440)
        }
    }
}
