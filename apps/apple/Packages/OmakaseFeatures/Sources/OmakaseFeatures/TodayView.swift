import OmakaseStore
import SwiftData
import SwiftUI

/// Focus's list view: today's tasks on the translucent ground, each a
/// `TaskRowView` with its priority pill. M3 adds the kanban board and timer.
public struct TodayView: View {
    @Query private var records: [TaskRecord]
    private let day: String
    private let toggle: (TaskRecord) -> Void

    public init(day: String, toggle: @escaping (TaskRecord) -> Void) {
        self.day = day
        self.toggle = toggle
        let target: String? = day
        _records = Query(filter: #Predicate<TaskRecord> { $0.scheduledDay == target })
    }

    public var body: some View {
        List {
            Section {
                ForEach(TodayModel.rows(records)) { row in
                    TaskRowView(title: row.title, priority: row.priority, isCompleted: row.isCompleted) {
                        toggleRow(row.id)
                    }
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text(day).sectionLabel()
            }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if records.isEmpty { ContentUnavailableView("Nothing scheduled for \(day)", systemImage: "sun.max") }
        }
        .navigationTitle("Focus")
    }

    private func toggleRow(_ id: String) {
        guard let record = records.first(where: { $0.id == id }) else { return }
        toggle(record)
    }
}
