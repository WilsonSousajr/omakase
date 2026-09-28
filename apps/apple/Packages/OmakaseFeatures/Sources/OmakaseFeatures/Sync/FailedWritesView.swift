import OmakaseStore
import SwiftUI

/// The failed-writes sheet: each write the server rejected, with what the
/// server said, and Retry and Discard. Monochrome; shu is never used
/// (M3.5 spec, Decisions: the indicator).
///
///     .sheet(isPresented: $showsFailedWrites) { FailedWritesView(model: model) }
public struct FailedWritesView: View {
    private let model: FailedWritesModel
    @Environment(\.dismiss) private var dismiss

    public init(model: FailedWritesModel) { self.model = model }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text("Failed writes").sectionLabel()
            if model.parked.isEmpty { emptyState } else { rows }
            HStack {
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.secondary).keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.xLarge)
        .frame(width: 460)
        .onAppear { model.refresh() }
        .confirmationDialog(
            "Discard this change?", isPresented: confirmingDiscard, titleVisibility: .visible,
            presenting: model.discardCandidate
        ) { write in
            Button("Discard", role: .destructive) { model.discard(write) }
            Button("Keep", role: .cancel) { model.cancelDiscard() }
        } message: { write in
            Text("\(write.actionTitle) never reached the server. Discarding it can't be undone.")
        }
    }

    private var emptyState: some View {
        Label("Nothing failed", systemImage: "checkmark.icloud")
            .font(TypeScale.body)
            .foregroundStyle(Palette.inkMuted.color)
            .frame(maxWidth: .infinity, minHeight: 80)
    }

    private var rows: some View {
        ScrollView {
            VStack(spacing: Spacing.small) {
                ForEach(model.parked) { write in
                    FailedWriteRowView(
                        write: write, retry: { model.retry(write) }, discard: { model.askToDiscard(write) })
                }
            }
        }
        .frame(maxHeight: 360)
    }

    private var confirmingDiscard: Binding<Bool> {
        Binding(get: { model.discardCandidate != nil }, set: { if !$0 { model.cancelDiscard() } })
    }
}

/// One rejected write: what it was, the server's message, and how long ago.
struct FailedWriteRowView: View {
    let write: ParkedWrite
    let retry: () -> Void
    let discard: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                Text(write.actionTitle).font(TypeScale.headline).foregroundStyle(Palette.ink.color)
                Text(write.lastError ?? "The server gave no reason.")
                    .font(TypeScale.body).foregroundStyle(Palette.inkMuted.color)
                Text(write.createdAt, format: .relative(presentation: .named))
                    .font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
            }
            Spacer()
            Button("Retry", action: retry).buttonStyle(.secondary)
            Button("Discard", action: discard).buttonStyle(.secondary)
        }
        .padding(Spacing.medium)
        .background(Palette.surface.color, in: .rect(cornerRadius: Radius.medium))
    }
}
