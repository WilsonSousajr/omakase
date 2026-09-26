import SwiftUI

/// M2 mockup: the pomodoro timer as a floating glass disc tinted by phase
/// (spec, Window structure: custom floating surfaces use `glassEffect`).
/// It takes plain values so M3 can drive it from the real timer.
public struct TimerGlassView: View {
    private let phase: TimerPhase
    private let remaining: String
    private let progress: Double

    private static let dial: CGFloat = 200
    private static let ring: CGFloat = 6

    public init(phase: TimerPhase, remaining: String, progress: Double) {
        self.phase = phase
        self.remaining = remaining
        self.progress = progress
    }

    public var body: some View {
        GlassEffectContainer(spacing: Spacing.large) {
            VStack(spacing: Spacing.large) {
                dial
                controls
            }
        }
    }

    private var dial: some View {
        ZStack {
            Circle().stroke(Palette.hairline.color, lineWidth: Self.ring)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(phase.tint.color, style: StrokeStyle(lineWidth: Self.ring, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: Spacing.tiny) {
                Text(phase.mockupTitle).sectionLabel()
                Text(remaining).font(TypeScale.display).monospacedDigit().foregroundStyle(Palette.ink.color)
            }
        }
        .frame(width: Self.dial, height: Self.dial)
        .padding(Spacing.xLarge)
        .glassEffect(.regular.tint(phase.tint.color.opacity(0.18)), in: .circle)
    }

    private var controls: some View {
        HStack(spacing: Spacing.medium) {
            Button {
            } label: {
                Image(systemName: "backward.end.fill")
            }.buttonStyle(.glass)
            Button {
            } label: {
                Image(systemName: "pause.fill").padding(.horizontal, Spacing.small)
            }
            .buttonStyle(.glassProminent)
            .tint(phase.tint.color)
            Button {
            } label: {
                Image(systemName: "forward.end.fill")
            }.buttonStyle(.glass)
        }
        .controlSize(.large)
    }
}

extension TimerPhase {
    /// Mockup copy; M3 owns the real, localisable strings.
    var mockupTitle: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short break"
        case .longBreak: "Long break"
        }
    }
}

/// All three phases side by side, for the gallery.
struct TimerPhasesView: View {
    var body: some View {
        HStack(spacing: Spacing.xLarge) {
            TimerGlassView(phase: .focus, remaining: "18:42", progress: 0.25)
            TimerGlassView(phase: .shortBreak, remaining: "03:10", progress: 0.4)
            TimerGlassView(phase: .longBreak, remaining: "12:05", progress: 0.2)
        }
    }
}

#Preview("Timer phases, dark") { TimerPhasesView().mockupCanvas(.dark) }
#Preview("Timer phases, light") { TimerPhasesView().mockupCanvas(.light) }
