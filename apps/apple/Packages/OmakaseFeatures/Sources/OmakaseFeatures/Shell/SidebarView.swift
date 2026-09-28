import OmakaseStore
import SwiftData
import SwiftUI

/// The main window's sidebar (spec §6, #260), inside macOS 26's floating
/// glass sidebar (glass-pass §2): the now strip; the day (Focus, Plan,
/// Review, Inbox); the places under Work, Study and Life, each counting its
/// open tasks; and the footer. It draws no background of its own so the
/// glass reads, and rows use the system's selection.
///
/// The kind headers are plain selectable rows, not `DisclosureGroup`
/// labels: every row here is a tagged row of the same `List`, so a click on
/// Work selects `.item(.projects)` exactly as a click on Plan selects Plan.
/// Sub-headers are the only rows that never select.
///
///     SidebarView(selection: $selection, day: day, models: models, openFocus: { … }, newTask: { … })
public struct SidebarView: View {
    @Binding private var selection: SidebarSelection?
    private let day: String
    private let models: ScreenModels
    private let openFocus: (String?) -> Void
    private let newTask: () -> Void
    @Environment(\.placeDirectory) private var directory
    // One query for every count here: the Inbox's and each place's (spec §6).
    @Query(filter: #Predicate<TaskRecord> { !$0.isCompleted }) private var openTasks: [TaskRecord]

    public init(
        selection: Binding<SidebarSelection?>, day: String, models: ScreenModels,
        openFocus: @escaping (String?) -> Void, newTask: @escaping () -> Void
    ) {
        _selection = selection
        (self.day, self.models, self.openFocus, self.newTask) = (day, models, openFocus, newTask)
    }

    public var body: some View {
        let counts = SidebarCounts.tally(openTasks.map(SidebarOpenTask.init))
        List(selection: $selection) {
            Section {
                ForEach(SidebarItem.day) { item in
                    SidebarRowView(item: item, count: item == .inbox ? TriageModel.badge(count: counts.inbox) : 0)
                        .tag(SidebarSelection.item(item))
                        .listItemTint(.fixed(AppTint.sidebarIcons.color))
                }
            }
            ForEach(SidebarPlaces.sections(directory, counts: counts)) { section in
                SidebarKindSectionView(section: section)
            }
        }
        .scrollContentBackground(.hidden)
        .safeAreaBar(edge: .top) { nowStrip }
        .safeAreaBar(edge: .bottom) {
            SidebarFooterView(settings: models.settings, failedWrites: models.failedWrites, newTask: newTask)
        }
        .navigationSplitViewColumnWidth(
            min: SidebarMetrics.minWidth, ideal: SidebarMetrics.idealWidth, max: SidebarMetrics.maxWidth)
    }

    @ViewBuilder private var nowStrip: some View {
        if let timer = models.timer { SidebarNowStripView(day: day, timer: timer, open: openFocus) }
    }
}

/// A kind's section: its selectable header, then its places, under their
/// workspace or semester sub-headers.
struct SidebarKindSectionView: View {
    let section: SidebarKindSection

    var body: some View {
        Section {
            SidebarKindHeaderView(section: section)
                .tag(section.selection)
                .listItemTint(.fixed(AppTint.sidebarIcons.color))
            ForEach(section.groups) { group in
                if let title = group.title { SidebarSubheaderView(title: title).selectionDisabled() }
                ForEach(group.rows) { row in SidebarPlaceRowView(row: row).tag(SidebarSelection.place(row.place)) }
            }
        }
    }
}
