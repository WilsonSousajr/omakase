import OmakaseStore
import SwiftData
import SwiftUI

/// Focus: the day as a List or a Kanban board, today's study blocks under it
/// (docs/design-system-apple.md, Layouts). Reads the store; writes go through
/// `FocusModel`'s injected actions, so they queue offline.
public struct FocusView: View {
    @Bindable private var model: FocusModel
    @Query private var records: [TaskRecord]
    @Query private var studies: [StudyBlockRecord]
    private let day: String

    public init(day: String, model: FocusModel) {
        (self.day, self.model) = (day, model)
        let target: String? = day
        _records = Query(filter: #Predicate<TaskRecord> { $0.scheduledDay == target || $0.isCarriedOver })
        _studies = Query(filter: #Predicate<StudyBlockRecord> { $0.scheduledDay == target })
    }

    public var body: some View {
        let board = FocusBoard(records: records)
        VStack(alignment: .leading, spacing: 0) {
            FocusHeaderView(day: day, layout: $model.layout)
            Divider().overlay(Palette.hairline.color)
            content(board).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if !studies.isEmpty {
                Divider().overlay(Palette.hairline.color)
                FocusStudyBlocksView(studies: studies)
            }
        }
        .onChange(of: board, initial: true) { _, board in model.keepSelection(in: board) }
        .navigationTitle("Focus")
    }

    @ViewBuilder private func content(_ board: FocusBoard) -> some View {
        if board.cards.isEmpty {
            ContentUnavailableView("Nothing scheduled for \(day)", systemImage: "sun.max")
        } else if model.layout == .kanban {
            FocusBoardKanbanView(board: board, model: model)
        } else {
            FocusBoardListView(board: board, model: model)
        }
    }
}

/// The day and the List/Kanban toggle.
struct FocusHeaderView: View {
    let day: String
    @Binding var layout: FocusModel.Layout

    var body: some View {
        HStack {
            Text(day).sectionLabel()
            Spacer()
            Picker("Layout", selection: $layout) {
                Text("List").tag(FocusModel.Layout.list)
                Text("Kanban").tag(FocusModel.Layout.kanban)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 160)
        }
        .padding(Spacing.large)
    }
}

/// Today's study blocks, under the board as on the web.
struct FocusStudyBlocksView: View {
    let studies: [StudyBlockRecord]

    var body: some View {
        HStack(spacing: Spacing.small) {
            Text("Study today").sectionLabel()
            ForEach(studies) { study in
                Label(label(study), systemImage: "book")
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

    private func label(_ study: StudyBlockRecord) -> String {
        study.estimatedMinutes.map { "\(study.title) · \($0)m" } ?? study.title
    }
}
