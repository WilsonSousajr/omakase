import SwiftUI

/// M2 mockup: the window (spec, Window structure). A sidebar, Today on opaque
/// paper/sumi, and an inspector for the selected task. Chrome keeps the
/// system's untinted glass.
struct ShellMockupView: View {
    @State private var inspecting = true

    var body: some View {
        NavigationSplitView {
            List { Label("Today", systemImage: "sun.max").tag(0) }
                .navigationSplitViewColumnWidth(180)
        } detail: {
            ShellTodayView()
                .inspector(isPresented: $inspecting) { ShellInspectorView() }
        }
        .tint(Palette.shu.color)
        .frame(width: 1000, height: 560)
    }
}

struct ShellTodayView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xLarge) {
                Text("Thursday, 25 September").sectionLabel()
                ForEach(MockupDay.toDo + MockupDay.inProgress + MockupDay.done) {
                    TaskRowView(title: $0.title, priority: $0.priority, isCompleted: $0.isCompleted)
                }
            }
            .padding(Spacing.xLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.background.color)
        .navigationTitle("Today")
    }
}

struct ShellInspectorView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text("Outline the thesis chapter").font(TypeScale.headline).foregroundStyle(Palette.ink.color)
            MockupSectionView(title: "Priority") {
                HStack(spacing: Spacing.small) {
                    Capsule().fill(PriorityMark.urgent.color).frame(width: 3, height: 16)
                    Text("Urgent").font(TypeScale.body).foregroundStyle(Palette.ink.color)
                }
            }
            MockupSectionView(title: "Scheduled") {
                Text("Today · 16:00, 90 min").font(TypeScale.body).foregroundStyle(Palette.ink.color)
            }
            Spacer()
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Shell, light") { ShellMockupView().preferredColorScheme(.light) }
#Preview("Shell, dark") { ShellMockupView().preferredColorScheme(.dark) }
