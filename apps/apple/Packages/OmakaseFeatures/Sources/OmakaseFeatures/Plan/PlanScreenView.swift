import OmakaseStore
import SwiftData
import SwiftUI

/// Plan over the store: the cached blocks, titled by their parent task or
/// study block, the classes and focus sessions RangeSync caches (#200), and
/// the day's open tasks. The visible days are read when Plan shows, when
/// they change, and after each catch-up while it shows (M4 spec, Decisions).
///
///     PlanScreenView(day: "2026-09-26", model: plan)
public struct PlanScreenView: View {
    private let model: PlanModel
    @Query private var tasks: [TaskRecord]
    /// Every cached task, for titles: a block moved to another day keeps its
    /// parent's name although the column only lists today's tasks (#203).
    @Query private var parentTasks: [TaskRecord]
    @Query private var blocks: [TimeBlockRecord]
    @Query private var studies: [StudyBlockRecord]
    @Query private var classes: [ClassOccurrenceRecord]
    @Query private var sessions: [SessionRecord]

    public init(day: String, model: PlanModel) {
        self.model = model
        let target: String? = day
        _tasks = Query(filter: #Predicate<TaskRecord> { $0.scheduledDay == target || $0.isCarriedOver })
    }

    public var body: some View {
        PlanView(
            model: model, items: blockItems + classItems + sessionItems, tasks: tasks.map { FocusCard(record: $0) }
        )
        .onAppear { model.show() }
        .onDisappear { model.hide() }
        .onChange(of: model.visibleDays) { model.refreshRange() }
    }

    private var blockItems: [CalendarItem] {
        let parents = parentTasks.map { ($0.id, $0.title) } + studies.map { ($0.id, $0.title) }
        let titles = Dictionary(parents) { first, _ in first }
        return blocks.compactMap { CalendarItem.block($0, titles: titles) }
    }

    private var classItems: [CalendarItem] { classes.compactMap { CalendarItem.classOccurrence($0) } }

    private var sessionItems: [CalendarItem] {
        sessions.compactMap { CalendarItem.focusSession($0, calendar: model.calendar) }
    }
}
