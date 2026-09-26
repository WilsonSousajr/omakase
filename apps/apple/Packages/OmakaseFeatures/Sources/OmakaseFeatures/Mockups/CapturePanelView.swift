import SwiftUI

/// M2 mockup: the ⌥⌘N capture panel that floats over any app (spec,
/// Capture). Neutral glass: capture is not a timer state, so it takes no tint.
struct CapturePanelView: View {
    @State private var text = "Email the advisor about the chapter deadline"

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.medium) {
                Image(systemName: "tray.and.arrow.down").foregroundStyle(Palette.shu.color)
                TextField("Capture a task…", text: $text)
                    .textFieldStyle(.plain)
                    .font(TypeScale.title)
            }
            HStack(spacing: Spacing.small) {
                Text("Inbox").sectionLabel()
                Spacer()
                Text("⏎ save · ⎋ dismiss").font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
            }
        }
        .padding(Spacing.xLarge)
        .frame(width: 600)
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.large))
    }
}

#Preview("Capture, dark") { CapturePanelView().mockupCanvas(.dark) }
#Preview("Capture, light") { CapturePanelView().mockupCanvas(.light) }
