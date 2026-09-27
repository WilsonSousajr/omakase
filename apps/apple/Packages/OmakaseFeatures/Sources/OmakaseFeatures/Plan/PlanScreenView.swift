import OmakaseStore
import SwiftData
import SwiftUI

/// Plan over the store: the cached blocks, titled by their parent task or
/// study block, and the day's open tasks. Classes and focus sessions join
/// `items` here once #200 caches them.
///
///     PlanScreenView(day: "2026-09-26", model: plan)
public struct PlanScreenView: View {
    private let model: PlanModel
    @Query private var tasks: [TaskRecord]
    @Query private var blocks: [TimeBlockRecord]
    @Query private var studies: [StudyBlockRecord]

    public init(day: String, model: PlanModel) {
        self.model = model
        let target: String? = day
        _tasks = Query(filter: #Predicate<TaskRecord> { $0.scheduledDay == target || $0.isCarriedOver })
    }

    public var body: some View {
        PlanView(model: model, items: blockItems, tasks: tasks.map { FocusCard(record: $0) })
    }

    private var blockItems: [CalendarItem] {
        let parents = tasks.map { ($0.id, $0.title) } + studies.map { ($0.id, $0.title) }
        let titles = Dictionary(parents) { first, _ in first }
        return blocks.compactMap { CalendarItem.block($0, titles: titles) }
    }
}
