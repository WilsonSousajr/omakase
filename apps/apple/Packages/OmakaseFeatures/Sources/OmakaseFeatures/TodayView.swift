import OmakaseStore
import SwiftData
import SwiftUI

/// M1's plain Today list. M2 gives it its look; M3 turns it into Focus.
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
        List(TodayModel.rows(records)) { row in
            Toggle(isOn: Binding(get: { row.isCompleted }, set: { _ in toggleRow(row.id) })) {
                Text(row.title).strikethrough(row.isCompleted)
            }
            .toggleStyle(.checkbox)
        }
        .overlay {
            if records.isEmpty { ContentUnavailableView("Nothing scheduled for \(day)", systemImage: "sun.max") }
        }
        .navigationTitle("Today")
    }

    private func toggleRow(_ id: String) {
        guard let record = records.first(where: { $0.id == id }) else { return }
        toggle(record)
    }
}
