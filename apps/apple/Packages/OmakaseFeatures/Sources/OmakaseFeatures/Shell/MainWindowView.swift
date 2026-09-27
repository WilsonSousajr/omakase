import OmakaseStore
import SwiftData
import SwiftUI

/// The main window: the sidebar of screens (places, spec §6, join it from
/// S7) and the detail each one shows. Moved out of the app target (#256) so
/// later M9 slices can grow and test it without `OmakaseMac`. No visible
/// change from the window `OmakaseMacApp` used to build inline (spec §3).
/// It publishes where a new task would go, for ⌘N, and its toolbar's ＋
/// opens capture with the same context (spec §4, #257).
///
///     MainWindowView(day: FocusDay().today, models: screenModels, openCapture: { capture?.show(context: $0) })
public struct MainWindowView: View {
    private let day: String
    private let models: ScreenModels
    private let openCapture: (CaptureContext) -> Void
    @SceneStorage("omakase.sidebar") private var selectionRaw = SidebarSelection.item(.focus).rawValue
    @Environment(\.modelContext) private var modelContext
    // Observed only to recompute the place directory when the library cache
    // changes (spec §8); the fetched arrays themselves go unused.
    @Query private var libraryProjects: [ProjectRecord]
    @Query private var libraryDisciplines: [DisciplineRecord]

    public init(day: String, models: ScreenModels, openCapture: @escaping (CaptureContext) -> Void) {
        (self.day, self.models, self.openCapture) = (day, models, openCapture)
    }

    public var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: itemSelection) { item in
                SidebarRowView(item: item).listItemTint(.fixed(AppTint.sidebarIcons.color))
            }
            .scrollContentBackground(.hidden)
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
    }

    /// Where ⌘N and ＋ file a new task from the screen shown (spec §4's
    /// table); reading Plan's anchor day follows it as Plan pages.
    private var captureContext: CaptureContext {
        .forSelection(selection, planDay: models.plan?.anchorDay)
    }

    /// Every row's kind mark reads this (spec §8); cheap to rebuild on a
    /// library change, and this view never observes the timer's tick.
    private var placeDirectory: PlaceDirectory {
        _ = (libraryProjects, libraryDisciplines)
        return PlaceDirectory.load(from: modelContext, today: day)
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
        case .item(.projects): if let projects = models.projects { ProjectsView(model: projects) }
        case .item(.study): if let study = models.study { StudyView(day: day, model: study) }
        // No place is ever selected yet (S7 lists them); a saved one falls
        // back to Focus below, but the switch must still cover it.
        case .item(.focus), .place:
            if let focus = models.focus, let timer = models.timer { FocusView(day: day, model: focus, timer: timer) }
        }
    }

    /// The persisted selection (spec §3), a place missing from the sidebar's
    /// known places falling back to Focus — every place, in this slice,
    /// since none are listed yet.
    private var selection: SidebarSelection {
        (SidebarSelection(rawValue: selectionRaw) ?? .item(.focus)).valid(knownPlaces: [])
    }

    private var itemSelection: Binding<SidebarItem?> {
        Binding(
            get: {
                guard case .item(let item) = selection else { return nil }
                return item
            },
            set: { selectionRaw = SidebarSelection.item($0 ?? .focus).rawValue }
        )
    }
}
