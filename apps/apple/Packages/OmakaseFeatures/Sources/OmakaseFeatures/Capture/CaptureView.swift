import OmakaseStore
import SwiftUI

/// The capture panel, from the M2 mockup (`Mockups/CapturePanelView`) and
/// spec §4: a neutral glass card, untinted because capture is not a timer
/// state (docs/design-system-apple.md, floating surfaces). The title, then
/// the kind chips and the parent chip, then the hint. ⏎ saves where the
/// context says, ⌘⏎ to the Inbox, ⌘1–3 pick the kind, ⎋ dismisses;
/// `onClose` closes the window around it.
///
///     CaptureView(model: CaptureModel(context: context, directory: directory, lastArea: .work, actions: actions),
///                 onClose: { panel.close() })
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
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack(spacing: Spacing.medium) {
                Image(systemName: "tray.and.arrow.down").foregroundStyle(Palette.inkMuted.color)
                TextField("Capture a task…", text: Binding(get: { model.draft }, set: { model.draft = $0 }))
                    .textFieldStyle(.plain)
                    .font(TypeScale.title)
                    .focused($isFieldFocused)
                    .onSubmit { closeIfSaved(model.saveEnter()) }
            }
            HStack(spacing: Spacing.medium) {
                KindChipsView(selection: Binding(get: { model.area }, set: { model.choose($0) }))
                Spacer()
                ParentMenuChip(
                    area: model.area, parent: Binding(get: { model.parent }, set: { model.choose(parent: $0) }),
                    directory: model.directory)
            }
            Text(model.hint).font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
        }
    }

    /// Key equivalents reach a button before the focused field's editor,
    /// so ⌘⏎, ⌘1–3 and ⎋ work while typing. The buttons take no space and
    /// are hidden from VoiceOver; the footer names the keys.
    private var shortcuts: some View {
        ZStack {
            Button("Save to Inbox") { closeIfSaved(model.saveInbox()) }.keyboardShortcut(.return, modifiers: .command)
            Button("Dismiss") { dismiss() }.keyboardShortcut(.cancelAction)
            ForEach(TaskArea.allCases, id: \.self) { area in
                Button(area.title) { model.choose(area) }
                    .keyboardShortcut(KeyEquivalent(Character(String(area.shortcutDigit))), modifiers: .command)
            }
        }
        .buttonStyle(.plain)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func closeIfSaved(_ saved: Bool) {
        guard saved else { return }
        onClose()
    }

    private func dismiss() {
        model.dismiss()
        onClose()
    }
}

#Preview("Capture") {
    let directory = PlaceDirectory(
        projects: [PlaceEntry(parent: .project("p1"), title: "Thesis", group: nil, color: KindTint.work)],
        disciplines: [
            PlaceEntry(parent: .discipline("d1"), title: "Linear algebra", group: nil, color: KindTint.study)
        ],
        semesterTitle: "Fall")
    let model = CaptureModel(
        context: CaptureContext(filing: TaskFiling(area: .study, parent: .discipline("d1"))), directory: directory,
        lastArea: .work, actions: .init(capture: { _ in }, remember: { _ in }))
    CaptureView(model: model, onClose: {}).padding(Spacing.xLarge)
}
