import SwiftUI

/// The pomodoro in the Focus panel: a glass disc tinted by phase, the ring in
/// the phase's colour, and its controls (docs/design-system-apple.md, Signals).
/// Starting focus runs on `taskID`, the panel's task.
public struct FocusTimerView: View {
    private let timer: TimerModel
    private let taskID: String?

    public init(timer: TimerModel, taskID: String?) { (self.timer, self.taskID) = (timer, taskID) }

    public var body: some View {
        GlassEffectContainer(spacing: Spacing.large) {
            VStack(spacing: Spacing.large) {
                dial
                FocusTimerControlsView(timer: timer, taskID: taskID)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var dial: some View {
        let tint = timer.state.phase.tint.color
        return ZStack {
            Circle().stroke(Palette.hairline.color, lineWidth: 6)
            Circle()
                .trim(from: 0, to: timer.progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: Spacing.tiny) {
                Text(timer.state.phase.title).sectionLabel()
                Text(timer.remainingText).font(TypeScale.display).monospacedDigit().foregroundStyle(Palette.ink.color)
            }
        }
        .frame(width: 180, height: 180)
        .padding(Spacing.large)
        .glassEffect(.regular.tint(tint.opacity(0.18)), in: .circle)
    }
}

/// Start (the one primary action) when waiting; pause or resume, and skip,
/// once running.
struct FocusTimerControlsView: View {
    let timer: TimerModel
    let taskID: String?

    var body: some View {
        HStack(spacing: Spacing.medium) {
            switch timer.state.status {
            case .idle:
                Button("Start \(timer.state.phase.title.lowercased())") { timer.start(taskID: taskID) }
                    .buttonStyle(.primary)
                    .disabled(timer.state.phase == .focus && taskID == nil)
            case .running:
                Button("Pause", systemImage: "pause.fill") { timer.pause() }.buttonStyle(.glass)
                Button("Skip", systemImage: "forward.end.fill") { timer.skip() }.buttonStyle(.glass)
            case .paused:
                Button("Resume", systemImage: "play.fill") { timer.resume() }.buttonStyle(.primary)
                Button("Skip", systemImage: "forward.end.fill") { timer.skip() }.buttonStyle(.glass)
            }
        }
        .controlSize(.large)
    }
}

extension TimerPhase {
    /// The phase's name as the timer shows it.
    var title: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short break"
        case .longBreak: "Long break"
        }
    }
}
