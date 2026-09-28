import SwiftUI

/// A Calendar.app event on the grid (#229): dashed and muted, with its
/// calendar's colour only on the stroke, because it is someone else's
/// commitment, not planned work. Never draggable.
struct CalendarExternalEventView: View {
    let item: CalendarItem

    var body: some View {
        let tint = item.color.color
        HStack(alignment: .top, spacing: Spacing.tiny) {
            Image(systemName: "calendar").font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
            Text(item.title).font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
            Spacer(minLength: 0)
        }
        .padding(Spacing.tiny)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tint.opacity(0.04), in: .rect(cornerRadius: Radius.small))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.small)
                .strokeBorder(tint.opacity(0.45), style: .init(dash: [4, 3]))
        }
        .clipShape(.rect(cornerRadius: Radius.small))
        .help(item.title)
    }
}

/// The header's "Calendar" toggle. Turning it on may bring the system's
/// access prompt; a denial explains where to grant it.
struct CalendarOverlayToggleView: View {
    let overlay: CalendarOverlayModel

    var body: some View {
        Toggle(isOn: isOn) {
            Label("Calendar", systemImage: "calendar.badge.clock")
        }
        .toggleStyle(.secondary)
        .help("Show Calendar.app's events behind your plan")
        .popover(isPresented: isShowingMessage) {
            Text(overlay.message ?? "").font(TypeScale.body).padding(Spacing.large).frame(width: 280)
        }
    }

    private var isOn: Binding<Bool> {
        Binding(get: { overlay.isEnabled }, set: { isOn in Task { await overlay.setEnabled(isOn) } })
    }

    private var isShowingMessage: Binding<Bool> {
        Binding(get: { overlay.message != nil }, set: { if !$0 { overlay.dismissMessage() } })
    }
}
