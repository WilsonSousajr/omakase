import OmakaseStore
import SwiftData
import SwiftUI

/// The main window: the sidebar of screens and places (spec §6; the
/// "Places" section below is a plain, temporary stand-in until S7 gives the
/// sidebar its real layout) and the detail each one shows. Moved out of the
/// app target (#256) so later M9 slices can grow and test it without
/// `OmakaseMac`. It publishes where a new task would go, for ⌘N, and its
/// toolbar's ＋ opens capture with the same context (spec §4, #257).
///
///     MainWindowView(day: FocusDay().today, models: screenModels, openCapture: { capture?.show(context: $0) })
public struct MainWindowView: View {
    private let day: String
    private let models: ScreenModels
    private let openCapture: (CaptureContext) -> Void
    @SceneStorage("omakase.sidebar") private var selectionRaw = SidebarSelection.item(.focus).rawValue
    @Environment(\.modelContext) private var modelContext
    @State private var placeDirectory = PlaceDirectory.empty
    // Observed only to know when to reload the place directory (spec §8);
    // read through `librarySnapshot` below, so a redraw for any other
    // reason - a selection change, the running timer's tick - never
    // triggers a fresh set of SwiftData fetches (#262 review). The
    // sidebar's Places section and `selection`'s fall-back to Focus both
    // read the cached `placeDirectory` this reloads (spec §5, #259).
    @Query private var libraryProjects: [ProjectRecord]
    @Query private var libraryDisciplines: [DisciplineRecord]

    public init(day: String, models: ScreenModels, openCapture: @escaping (CaptureContext) -> Void) {
        (self.day, self.models, self.openCapture) = (day, models, openCapture)
    }

    public var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .toolbar {
            if let failedWrites = models.failedWrites {
                ToolbarItem(placement: .primaryAction) { SyncIndicatorView(model: failedWrites) }
            }
            // Until S8 settles the toolbar (spec §7): ＋ opens capture as ⌘N does.
            ToolbarItem(placement: .primaryAction) {
                Button("New Task", systemImage: "plus") { openCapture(captureContext) }
                    .help("New Task (⌘N)")
            }
        }
        .focusedSceneValue(\.newTaskContext, captureContext)
        .environment(\.placeDirectory, placeDirectory)
        .onChange(of: librarySnapshot, initial: true) { _, _ in reloadPlaces() }
    }

    private var sidebar: some View {
        List(selection: sidebarSelection) {
            ForEach(SidebarItem.allCases) { item in
                SidebarRowView(item: item).tag(SidebarSelection.item(item))
                    .listItemTint(.fixed(AppTint.sidebarIcons.color))
            }
            Section("Places") {
                ForEach(placeDirectory.places(for: .work)) { entry in placeRow(entry, symbol: TaskArea.work.symbol) }
                ForEach(placeDirectory.places(for: .study)) { entry in
                    placeRow(entry, symbol: TaskArea.study.symbol)
                }
                Label("Life", systemImage: TaskArea.life.symbol).tag(SidebarSelection.place(.life))
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func placeRow(_ entry: PlaceEntry, symbol: String) -> some View {
        Label(entry.title, systemImage: symbol).tag(SidebarSelection.place(PlaceDirectory.place(for: entry.parent)))
    }

    /// Opens a place from elsewhere on the screen (spec §6): a project
    /// card's double-click, ⏎ on a selected one, or its context menu's Open.
    private func open(_ place: TaskPlace) { selectionRaw = SidebarSelection.place(place).rawValue }

    /// Where ⌘N and ＋ file a new task from the screen shown (spec §4's
    /// table); reading Plan's anchor day follows it as Plan pages.
    private var captureContext: CaptureContext {
        .forSelection(selection, planDay: models.plan?.anchorDay)
    }

    private var librarySnapshot: PlaceLibrarySnapshot {
        PlaceLibrarySnapshot(today: day, projects: libraryProjects, disciplines: libraryDisciplines)
    }

    /// Every row's kind mark, the sidebar's Places section and a place
    /// selection's validity all read `placeDirectory` (spec §5, §8);
    /// reloaded only when `librarySnapshot` changes, never on a redraw for
    /// some other reason - an archived project still reaches this on the
    /// next catch-up, since that changes a `ProjectRecord`'s `status`.
    private func reloadPlaces() {
        placeDirectory = PlaceDirectory.load(from: modelContext, today: day)
    }

    @ViewBuilder private var detail: some View {
        switch selection {
        // Plan's panel acts through Focus's model, so its Complete, Reschedule,
        // Remind me and the editor's Save queue exactly as Focus's do (#217, #218).
        case .item(.plan):
            if let plan = models.plan, let focus = models.focus {
                PlanScreenView(day: day, model: plan, focus: focus, overlay: models.calendarOverlay)
            }
        case .item(.review): if let review = models.review { ReviewView(day: day, model: review) }
        case .item(.inbox): if let inbox = models.inbox { InboxView(day: day, model: inbox) }
        case .item(.projects): if let projects = models.projects { ProjectsView(model: projects, open: open) }
        case .item(.study): if let study = models.study { StudyView(day: day, model: study) }
        case .item(.focus):
            if let focus = models.focus, let timer = models.timer { FocusView(day: day, model: focus, timer: timer) }
        // A place's own list (spec §5): the same triage actions the Inbox uses.
        case .place(let place):
            if let places = models.places, let triage = models.inbox {
                PlaceTasksView(place: place, day: day, model: places, triage: triage)
            }
        }
    }

    /// The persisted selection (spec §3): a place missing from the
    /// directory's known places — deleted or archived since it was saved —
    /// falls back to Focus.
    private var selection: SidebarSelection {
        (SidebarSelection(rawValue: selectionRaw) ?? .item(.focus)).valid(knownPlaces: placeDirectory.knownPlaces)
    }

    private var sidebarSelection: Binding<SidebarSelection?> {
        Binding(get: { selection }, set: { selectionRaw = ($0 ?? .item(.focus)).rawValue })
    }
}
