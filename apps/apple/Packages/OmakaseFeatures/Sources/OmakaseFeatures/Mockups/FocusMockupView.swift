import SwiftUI

/// M2 mockup: Focus, as the web client had it, plus a list view. The day as a
/// kanban board (To do / In progress / Done) or a list, today's study blocks
/// underneath, and the active task on the right: timer, subtasks, notes.
struct FocusMockupView: View {
    @State var layout: FocusBoardLayout

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                FocusBoardHeaderView(layout: $layout)
                Divider().overlay(Palette.hairline.color)
                Group {
                    if layout == .kanban { FocusKanbanView() } else { FocusListView() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Divider().overlay(Palette.hairline.color)
                FocusStudyStripView()
            }
            Divider().overlay(Palette.hairline.color)
            FocusActiveTaskView().frame(width: 360)
        }
    }
}

enum FocusBoardLayout: String, CaseIterable {
    case list = "List"
    case kanban = "Kanban"
}

struct FocusBoardHeaderView: View {
    @Binding var layout: FocusBoardLayout

    var body: some View {
        HStack {
            Text("Today").font(TypeScale.title).foregroundStyle(Palette.ink.color)
            Spacer()
            Picker("Layout", selection: $layout) {
                ForEach(FocusBoardLayout.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 160)
        }
        .padding(Spacing.large)
    }
}

struct FocusKanbanView: View {
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            column("To do", MockupDay.toDo)
            column("In progress", MockupDay.inProgress)
            column("Done", MockupDay.done)
        }
        .padding(Spacing.large)
    }

    private func column(_ title: String, _ items: [MockupDay.Item]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("\(title) · \(items.count)").sectionLabel()
            ForEach(items) { FocusCardView(item: $0) }
            Spacer(minLength: 0)
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.surface.color.opacity(0.35), in: .rect(cornerRadius: Radius.large))
    }
}

/// A kanban card: title, then its estimate and priority badge.
struct FocusCardView: View {
    let item: MockupDay.Item

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(item.title)
                .font(TypeScale.body)
                .strikethrough(item.isCompleted)
                .foregroundStyle((item.isCompleted ? Palette.inkMuted : Palette.ink).color)
            HStack(spacing: Spacing.small) {
                PriorityBadgeView(priority: item.priority)
                Text("\(item.minutes)m").font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface.color, in: .rect(cornerRadius: Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: Radius.medium).strokeBorder(Palette.hairline.color))
    }
}

struct FocusListView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {
            section("In progress", MockupDay.inProgress)
            section("To do", MockupDay.toDo)
            section("Done", MockupDay.done)
        }
        .padding(Spacing.xLarge)
    }

    private func section(_ title: String, _ items: [MockupDay.Item]) -> some View {
        MockupSectionView(title: title) {
            ForEach(items) {
                TaskRowView(title: $0.title, priority: $0.priority, minutes: $0.minutes, isCompleted: $0.isCompleted)
            }
        }
    }
}

/// Today's study blocks, under the board as on the web.
struct FocusStudyStripView: View {
    var body: some View {
        HStack(spacing: Spacing.small) {
            Text("Study today").sectionLabel()
            ForEach(MockupDay.studyBlocks, id: \.self) { title in
                Label(title, systemImage: "book")
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.ink.color)
                    .padding(.horizontal, Spacing.small)
                    .padding(.vertical, Spacing.tiny)
                    .background(Palette.indigo.color.opacity(0.12), in: .capsule)
            }
            Spacer()
        }
        .padding(Spacing.medium)
    }
}

/// The right panel: the task being worked, its timer, subtasks and notes.
struct FocusActiveTaskView: View {
    @State private var notes = "Contrast pinned in tests; dark shu moved to #D0462C."

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text("Write the M2 design record").font(TypeScale.headline).foregroundStyle(Palette.ink.color)
            TimerGlassView(phase: .focus, remaining: "18:42", progress: 0.25).frame(maxWidth: .infinity)
            MockupSectionView(title: "Subtasks") {
                ForEach(MockupDay.subtasks) { TaskRowView(title: $0.title, priority: "", isCompleted: $0.isCompleted) }
            }
            MockupSectionView(title: "Notes") {
                TextEditor(text: $notes)
                    .font(TypeScale.body)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.small)
                    .background(Palette.surface.color, in: .rect(cornerRadius: Radius.medium))
            }
        }
        .padding(Spacing.large)
    }
}

#Preview("Focus kanban, dark") {
    FocusMockupView(layout: .kanban).frame(width: 1120, height: 720).mockupWindow(.dark)
}
#Preview("Focus list, dark") {
    FocusMockupView(layout: .list).frame(width: 1120, height: 720).mockupWindow(.dark)
}
#Preview("Focus kanban, light") {
    FocusMockupView(layout: .kanban).frame(width: 1120, height: 720).mockupWindow(.light)
}
