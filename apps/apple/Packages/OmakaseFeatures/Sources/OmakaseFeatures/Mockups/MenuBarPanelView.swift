import SwiftUI

/// M2 mockup: the window-style `MenuBarExtra` (spec, Menu bar). The running
/// timer, the current and next block, what is left today, and capture.
struct MenuBarPanelView: View {
    @State private var capture = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            MenuBarTimerRowView()
            Divider().overlay(Palette.hairline.color)
            MockupSectionView(title: "Now · Next") {
                blockLine("14:00", "Write the M2 design record", tint: Palette.shu)
                blockLine("15:30", "Linear algebra lecture", tint: Palette.indigo)
            }
            MockupSectionView(title: "Left today · 4") {
                ForEach(MockupDay.toDo.prefix(3)) {
                    TaskRowView(title: $0.title, priority: $0.priority, isCompleted: false)
                }
            }
            TextField("Capture…", text: $capture)
                .textFieldStyle(.roundedBorder)
        }
        .padding(Spacing.large)
        .frame(width: 320)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Palette.background.color.opacity(Translucency.window)
            }
            .clipShape(.rect(cornerRadius: Radius.large))
        }
    }

    private func blockLine(_ time: String, _ title: String, tint: DesignColor) -> some View {
        HStack(spacing: Spacing.small) {
            Circle().fill(tint.color).frame(width: 6, height: 6)
            Text(time).font(TypeScale.caption).monospacedDigit().foregroundStyle(Palette.inkMuted.color)
            Text(title).font(TypeScale.body).foregroundStyle(Palette.ink.color).lineLimit(1)
        }
    }
}

struct MenuBarTimerRowView: View {
    var body: some View {
        HStack(spacing: Spacing.medium) {
            Circle().fill(TimerPhase.focus.tint.color).frame(width: 10, height: 10)
            Text("18:42").font(TypeScale.title).monospacedDigit().foregroundStyle(Palette.ink.color)
            Text("Focus").sectionLabel()
            Spacer()
            GlassEffectContainer(spacing: Spacing.small) {
                HStack(spacing: Spacing.small) {
                    Button {
                    } label: {
                        Image(systemName: "pause.fill")
                    }.buttonStyle(.glass)
                    Button {
                    } label: {
                        Image(systemName: "forward.end.fill")
                    }.buttonStyle(.glass)
                }
            }
        }
    }
}

#Preview("Menu bar, dark") { MenuBarPanelView().mockupCanvas(.dark) }
#Preview("Menu bar, light") { MenuBarPanelView().mockupCanvas(.light) }
