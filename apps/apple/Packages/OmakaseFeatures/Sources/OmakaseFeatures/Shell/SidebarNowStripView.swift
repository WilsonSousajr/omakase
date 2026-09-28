import OmakaseStore
import SwiftData
import SwiftUI

/// The sidebar's now strip (spec §6, #260): the running phase's ring,
/// countdown and task, the same dimmed while paused, "Next · 14:00 Title"
/// when idle with a block later today, and nothing otherwise. Clicking it
/// opens Focus on its task.
///
/// The only sidebar view that reads the timer, so the timer's per-second
/// tick redraws this strip and nothing else in the sidebar.
///
///     SidebarNowStripView(day: day, timer: timer) { taskID in openFocus(taskID) }
public struct SidebarNowStripView: View {
    private let timer: TimerModel
    private let open: (String?) -> Void
    // Today's tasks and the carried-over, as the menu-bar panel reads them:
    // the timer only ever runs on one of Focus's tasks.
    @Query private var tasks: [TaskRecord]
    @Query private var blocks: [TimeBlockRecord]

    public init(day: String, timer: TimerModel, open: @escaping (String?) -> Void) {
        (self.timer, self.open) = (timer, open)
        let target: String? = day
        _tasks = Query(filter: #Predicate<TaskRecord> { $0.scheduledDay == target || $0.isCarriedOver })
        _blocks = Query(filter: #Predicate<TimeBlockRecord> { $0.day == day })
    }

    public var body: some View {
        let state = self.state
        if state != .idle {
            Button {
                open(state.taskID)
            } label: {
                NowStripContentView(state: state)
            }
            .buttonStyle(.plain)
            .help("Open in Focus")
        }
    }

    /// Read on every tick: `timer.now` moves each second.
    private var state: NowStripState {
        let slots = blocks.map { SessionBlock.Slot(id: $0.id, taskID: $0.taskID, start: $0.startTime, end: $0.endTime) }
        let next = MenuBar.nextBlock(in: slots, after: DayString.time(timer.now, calendar: .current))
        return NowStrip.state(
            timer: NowStripTimer(timer, title: title(of: timer.state.taskID)),
            nextBlock: next.map { NowStripNext(slot: $0, title: title(of: $0.taskID)) })
    }

    private func title(of taskID: String?) -> String? {
        guard let taskID else { return nil }
        return tasks.first { $0.id == taskID }?.title
    }
}

/// What the strip draws for a state: the phase row, dimmed while paused,
/// or the next block's line.
struct NowStripContentView: View {
    let state: NowStripState

    var body: some View {
        Group {
            switch state {
            case .running(let phase): NowStripPhaseRowView(phase: phase)
            case .paused(let phase):
                NowStripPhaseRowView(phase: phase).opacity(SidebarMetrics.pausedOpacity)
                    .accessibilityValue("Paused")
            case .next(let title, let start, _): NowStripNextRowView(title: title, start: start)
            case .idle: EmptyView()
            }
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

/// The phase's ring in its colour, the countdown rolling digit by digit,
/// and the task.
struct NowStripPhaseRowView: View {
    let phase: NowStripPhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.small) {
            NowStripRingView(phase: phase.phase, progress: phase.progress)
            Text(phase.remaining)
                .font(TypeScale.headline)
                .monospacedDigit()
                .foregroundStyle(Palette.ink.color)
                .contentTransition(Motion.digits(reduceMotion: reduceMotion))
                .motion(Motion.select, value: phase.remaining)
            Text(phase.title)
                .font(TypeScale.body)
                .foregroundStyle(Palette.ink.color)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A small ring: the track, and the arc run so far in the phase's colour.
struct NowStripRingView: View {
    let phase: TimerPhase
    let progress: Double

    var body: some View {
        ZStack {
            // inkMuted, as the Focus dial's track: the hairline vanished on dark glass (#173).
            Circle().stroke(Palette.inkMuted.color, lineWidth: SidebarMetrics.ringLineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(phase.tint.color, style: StrokeStyle(lineWidth: SidebarMetrics.ringLineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: SidebarMetrics.ringDiameter, height: SidebarMetrics.ringDiameter)
        .frame(width: SidebarMetrics.iconColumn)
        .accessibilityHidden(true)
    }
}

/// "Next · 14:00 Title": the day's next block, when no phase is on.
struct NowStripNextRowView: View {
    let title: String
    let start: String

    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: "clock")
                .foregroundStyle(Palette.inkMuted.color)
                .frame(width: SidebarMetrics.iconColumn)
            Text("Next · \(start)").sectionLabel().monospacedDigit()
            Text(title)
                .font(TypeScale.body)
                .foregroundStyle(Palette.ink.color)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .accessibilityElement(children: .combine)
    }
}
