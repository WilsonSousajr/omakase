import SwiftUI

/// The toolbar's sync item: the glyph and a short label, on the system's own
/// untinted glass. A tap opens the failed-writes sheet when something is
/// parked, and otherwise a popover with the status and Sync now.
///
///     .toolbar { ToolbarItem(placement: .primaryAction) { SyncIndicatorView(model: failedWrites) } }
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
        .help(model.indicator.label)
        .popover(isPresented: $showsStatus, arrowEdge: .bottom) { SyncStatusPopoverView(model: model) }
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
            Button("Sync now") { model.syncNow() }.buttonStyle(.glass)
        }
        .padding(Spacing.large)
    }
}
