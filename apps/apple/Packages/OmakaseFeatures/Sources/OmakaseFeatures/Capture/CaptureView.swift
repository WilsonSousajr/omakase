import SwiftUI

/// The ⌥⌘N capture panel, from the M2 mockup (`Mockups/CapturePanelView`):
/// a neutral glass card, untinted because capture is not a timer state
/// (docs/design-system-apple.md, floating surfaces). ⏎ saves for today,
/// ⌘⏎ to the Inbox, ⎋ dismisses; `onClose` closes the window around it.
///
///     CaptureView(model: CaptureModel(actions: actions), onClose: { panel.close() })
public struct CaptureView: View {
    private let model: CaptureModel
    private let onClose: () -> Void
    @FocusState private var isFieldFocused: Bool

    private static let width: CGFloat = 600

    public init(model: CaptureModel, onClose: @escaping () -> Void) {
        self.model = model
        self.onClose = onClose
    }

    public var body: some View {
        GlassEffectContainer {
            card
                .padding(Spacing.xLarge)
                .frame(width: Self.width)
                .glassEffect(.regular, in: .rect(cornerRadius: Radius.large))
        }
        .background { shortcuts }
        .onAppear { isFieldFocused = true }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.medium) {
                Image(systemName: "tray.and.arrow.down").foregroundStyle(Palette.inkMuted.color)
                TextField("Capture a task…", text: Binding(get: { model.draft }, set: { model.draft = $0 }))
                    .textFieldStyle(.plain)
                    .font(TypeScale.title)
                    .focused($isFieldFocused)
                    .onSubmit { save(to: CaptureModel.enterDestination) }
            }
            HStack(spacing: Spacing.small) {
                Text(CaptureModel.enterDestination.title).sectionLabel()
                Spacer()
                Text(CaptureModel.hint).font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
            }
        }
    }

    /// Key equivalents reach a button before the focused field's editor,
    /// so ⌘⏎ and ⎋ work while typing. The buttons take no space and are
    /// hidden from VoiceOver; the footer names the keys.
    private var shortcuts: some View {
        ZStack {
            Button("Save to Inbox") { save(to: .inbox) }.keyboardShortcut(.return, modifiers: .command)
            Button("Dismiss") { dismiss() }.keyboardShortcut(.cancelAction)
        }
        .buttonStyle(.plain)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func save(to destination: CaptureDestination) {
        guard model.save(to: destination) else { return }
        onClose()
    }

    private func dismiss() {
        model.dismiss()
        onClose()
    }
}

#Preview("Capture") {
    CaptureView(model: CaptureModel(actions: .init(capture: { _, _ in })), onClose: {}).padding(Spacing.xLarge)
}
