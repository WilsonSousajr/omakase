import SwiftUI

/// The sidebar's foot (spec §6, #260; glass-pass §1–§2): ＋ New Task with
/// its ⌘N, the account, which opens Settings, and the sync indicator,
/// moved here from the toolbar. One shape family: New Task and sync are
/// `.secondary` capsules, the account an `.icon` circle, all
/// `ControlMetrics.height` tall.
///
///     SidebarFooterView(settings: models.settings, failedWrites: models.failedWrites) { openCapture(context) }
public struct SidebarFooterView: View {
    private let settings: SettingsModel?
    private let failedWrites: FailedWritesModel?
    private let newTask: () -> Void

    public init(settings: SettingsModel?, failedWrites: FailedWritesModel?, newTask: @escaping () -> Void) {
        (self.settings, self.failedWrites, self.newTask) = (settings, failedWrites, newTask)
    }

    public var body: some View {
        VStack(spacing: Spacing.small) {
            Button(action: newTask) { SidebarNewTaskLabelView() }
                .buttonStyle(.secondary)
                .help("New Task (⌘N)")
            HStack(spacing: Spacing.small) {
                SidebarAccountView(email: settings?.email)
                Spacer(minLength: Spacing.small)
                // Its label never wraps: the address beside it truncates instead.
                if let failedWrites { SyncIndicatorView(model: failedWrites).fixedSize() }
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        // Read online, as Settings' Account tab reads it; an offline read keeps
        // the last known address, and "Account" shows only before the first.
        .task { await settings?.loadAccount() }
    }
}

/// "＋ New Task" with ⌘N at the far end. The shortcut is only shown:
/// File › New Task already owns ⌘N (spec §4), so a second binding here
/// would fight it.
struct SidebarNewTaskLabelView: View {
    var body: some View {
        HStack(spacing: Spacing.small) {
            Label("New Task", systemImage: "plus")
            Spacer(minLength: Spacing.small)
            Text("⌘N").foregroundStyle(Palette.inkMuted.color).accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The account: a glass circle with the address's initial, which opens
/// Settings, and the address beside it.
struct SidebarAccountView: View {
    let email: String?

    var body: some View {
        HStack(spacing: Spacing.small) {
            SettingsLink {
                Label {
                    Text("Settings")
                } icon: {
                    initial
                }
            }
            .buttonStyle(.icon)
            .help("Settings (⌘,)")
            Text(email ?? "Account")
                .font(TypeScale.caption)
                .foregroundStyle(Palette.inkMuted.color)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    /// The address's first letter, or a person before it has loaded.
    @ViewBuilder private var initial: some View {
        if let letter = email?.first {
            Text(String(letter).uppercased())
        } else {
            Image(systemName: "person.fill")
        }
    }
}
