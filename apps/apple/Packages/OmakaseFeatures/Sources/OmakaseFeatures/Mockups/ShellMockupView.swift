import SwiftUI

/// M2 mockup: the window, with the web client's navigation. Plan, Focus,
/// Review, Projects and Study in the sidebar, the account and Settings at its
/// foot. Chrome keeps the system's untinted glass; content is opaque.
struct ShellMockupView: View {
    @State var selection: ShellSection = .plan

    var body: some View {
        NavigationSplitView {
            List(ShellSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.symbol).tag(section)
            }
            .safeAreaInset(edge: .bottom) { ShellAccountView() }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            detail.navigationTitle(selection.rawValue)
        }
        .tint(Palette.shu.color)
    }

    @ViewBuilder private var detail: some View {
        switch selection {
        case .plan: PlanMockupView()
        case .focus: FocusMockupView(layout: .kanban)
        default:
            ContentUnavailableView(
                selection.rawValue, systemImage: selection.symbol, description: Text("Not mocked in M2"))
        }
    }
}

enum ShellSection: String, CaseIterable, Identifiable {
    case plan = "Plan"
    case focus = "Focus"
    case review = "Review"
    case projects = "Projects"
    case study = "Study"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .plan: "calendar"
        case .focus: "scope"
        case .review: "checkmark.square"
        case .projects: "folder"
        case .study: "book"
        }
    }
}

struct ShellAccountView: View {
    var body: some View {
        HStack(spacing: Spacing.small) {
            Circle().fill(Palette.surface.color).frame(width: 24, height: 24)
                .overlay(Text("W").font(TypeScale.caption).foregroundStyle(Palette.ink.color))
            Text("will").font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
            Spacer()
            Image(systemName: "gearshape").foregroundStyle(Palette.inkMuted.color)
        }
        .padding(Spacing.medium)
    }
}

#Preview("Shell, Plan, light") {
    ShellMockupView(selection: .plan).frame(width: 1300, height: 760).preferredColorScheme(.light)
}
#Preview("Shell, Focus, dark") {
    ShellMockupView(selection: .focus).frame(width: 1300, height: 760).preferredColorScheme(.dark)
}
