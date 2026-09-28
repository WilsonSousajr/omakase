import OmakaseStore
import SwiftData
import SwiftUI

/// The menu-bar extra's panel (spec, Menu bar): the running timer and its
/// controls, the task it runs on, the next block, and what's left today.
/// Clicking a task focuses it in the main window.
public struct MenuBarTimerPanelView: View {
    private let timer: TimerModel
    private let select: (String) -> Void
    private let today: String
    @Query private var tasks: [TaskRecord]
    @Query private var blocks: [TimeBlockRecord]
    @State private var placeDirectory = PlaceDirectory.empty
    // Observed only to know when to reload the place directory (spec §8);
    // read through `librarySnapshot` below, so this panel's body - which
    // redraws every second while `timer.now` ticks - never refetches it.
    @Query private var libraryProjects: [ProjectRecord]
    @Query private var libraryDisciplines: [DisciplineRecord]
    @Environment(\.modelContext) private var modelContext

    public init(day: String, timer: TimerModel, select: @escaping (String) -> Void) {
        (self.timer, self.select, today) = (timer, select, day)
        let target: String? = day
        _tasks = Query(filter: #Predicate<TaskRecord> { $0.scheduledDay == target || $0.isCarriedOver })
        _blocks = Query(filter: #Predicate<TimeBlockRecord> { $0.day == day })
    }

    public var body: some View {
        let board = FocusBoard(records: tasks)
        VStack(alignment: .leading, spacing: Spacing.large) {
            TimerBarRowView(timer: timer, taskID: timer.state.taskID ?? board.columns.first?.cards.first?.id)
            if let title = title(of: timer.state.taskID) {
                Text(title).font(TypeScale.headline).foregroundStyle(Palette.ink.color)
            }
            Divider().overlay(Palette.hairline.color)
            if let next = MenuBar.nextBlock(in: slots, after: DayString.time(timer.now, calendar: .current)) {
                TimerBarLineView(
                    label: "Next", time: String(next.start.prefix(5)), title: title(of: next.taskID) ?? "Study")
            }
            TimerBarLeftTodayView(cards: board.columns.first?.cards ?? [], select: select)
        }
        .padding(Spacing.large)
        .frame(width: 320)
        // Its own root, apart from the main window's environment (spec §4, #214).
        .environment(\.placeDirectory, placeDirectory)
        .onChange(of: librarySnapshot, initial: true) { _, _ in reloadPlaces() }
    }

    private var librarySnapshot: PlaceLibrarySnapshot {
        PlaceLibrarySnapshot(today: today, projects: libraryProjects, disciplines: libraryDisciplines)
    }

    /// Reloaded only when `librarySnapshot` changes, never on the timer's tick.
    private func reloadPlaces() {
        placeDirectory = PlaceDirectory.load(from: modelContext, today: today)
    }

    private var slots: [SessionBlock.Slot] {
        blocks.map { SessionBlock.Slot(id: $0.id, taskID: $0.taskID, start: $0.startTime, end: $0.endTime) }
    }

    private func title(of taskID: String?) -> String? {
        guard let taskID else { return nil }
        return tasks.first { $0.id == taskID }?.title
    }
}

/// The phase dot, the countdown, and the timer's controls.
struct TimerBarRowView: View {
    let timer: TimerModel
    let taskID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack(spacing: Spacing.small) {
                Circle().fill(timer.state.phase.tint.color).frame(width: 10, height: 10)
                Text(timer.remainingText).font(TypeScale.title).monospacedDigit().foregroundStyle(Palette.ink.color)
                Text(timer.state.phase.title).sectionLabel()
            }
            FocusTimerControlsView(timer: timer, taskID: taskID)
        }
    }
}

struct TimerBarLineView: View {
    let label: String
    let time: String
    let title: String

    var body: some View {
        HStack(spacing: Spacing.small) {
            Text(label).sectionLabel()
            Text(time).font(TypeScale.caption).monospacedDigit().foregroundStyle(Palette.inkMuted.color)
            Text(title).font(TypeScale.body).foregroundStyle(Palette.ink.color).lineLimit(1)
        }
    }
}

/// Today's open tasks, carried-over first; clicking one focuses it.
struct TimerBarLeftTodayView: View {
    let cards: [FocusCard]
    let select: (String) -> Void
    @Environment(\.placeDirectory) private var directory

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Left today · \(cards.count)").sectionLabel()
            ForEach(cards.prefix(5)) { card in
                Button {
                    select(card.id)
                } label: {
                    HStack {
                        KindMarkView(mark: directory.mark(for: card.filing))
                        Text(card.title).font(TypeScale.body).foregroundStyle(Palette.ink.color).lineLimit(1)
                        Spacer()
                        if PriorityMark.showsInRow(card.priority) { PriorityBadgeView(priority: card.priority) }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
