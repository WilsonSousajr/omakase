import SwiftUI

/// The sync item: the glyph and a short label. A tap opens the
/// failed-writes sheet when something is parked, and otherwise a popover
/// with the status and Sync now. It lived in the toolbar, on the system's
/// own untinted glass, until the sidebar's footer took it (spec §6, #260);
/// there it is a `.secondary` capsule, like every other button beside it.
///
///     SidebarFooterView(settings: settings, failedWrites: failedWrites) { … }   // draws SyncIndicatorView(model:)
public struct SyncIndicatorView: View {
    private let model: FailedWritesModel
    @State private var showsFailedWrites = false
    @State private var showsStatus = false

    public init(model: FailedWritesModel) { self.model = model }

    public var body: some View {
        Button(action: open) {
            Label(model.indicator.label, systemImage: model.indicator.symbol)
                .labelStyle(.titleAndIcon)
                .symbolRenderingMode(.monochrome)
        }
        .buttonStyle(.secondary)
        .help(model.indicator.label)
        // Opens upward: the footer sits at the window's bottom edge.
        .popover(isPresented: $showsStatus, arrowEdge: .top) { SyncStatusPopoverView(model: model) }
        .sheet(isPresented: $showsFailedWrites) { FailedWritesView(model: model) }
    }

    private func open() {
        model.refresh()
        if model.indicator.opensFailedWrites { showsFailedWrites = true } else { showsStatus = true }
    }
}

/// The status line, when the next backed-off write is due, and Sync now.
struct SyncStatusPopoverView: View {
    let model: FailedWritesModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Label(model.indicator.label, systemImage: model.indicator.symbol)
                .font(TypeScale.headline)
                .foregroundStyle(Palette.ink.color)
            if let due = model.status.nextAttemptAt {
                Text("Next try at \(due, style: .time)").font(TypeScale.caption)
                    .foregroundStyle(Palette.inkMuted.color)
            }
            Button("Sync now") { model.syncNow() }.buttonStyle(.secondary)
        }
        .padding(Spacing.large)
    }
}
