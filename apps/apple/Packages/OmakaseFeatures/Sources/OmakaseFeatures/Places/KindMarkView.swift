import SwiftUI

/// What a task is for, on its row (spec §8): a kind-coloured bar and the
/// place's name, so a list of mixed Work, Study and Life tasks still reads
/// at a glance without repeating each task's own title.
///
///     KindMarkView(mark: directory.mark(for: task.filing))
public struct KindMarkView: View {
    private let mark: KindMark

    public init(mark: KindMark) { self.mark = mark }

    public var body: some View {
        HStack(spacing: Spacing.tiny) {
            Capsule().fill(mark.color.color).frame(width: 3, height: 12)
            Text(mark.title)
                .font(TypeScale.caption)
                .foregroundStyle(Palette.inkMuted.color)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
