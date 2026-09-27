import SwiftUI

/// A block or a class on the grid (design-system-apple, Signals; spec §9): a
/// block wears its source's colour as a 3-pt bar, a faint fill on an opaque
/// surface, and its kind's glyph beside the title, with the time range
/// under it once it is tall enough; a class is dashed with a book glyph
/// instead of a bar, because it is fixed, not planned. A cancelled class
/// stays, struck through and dimmed (#207): it is information, not absence.
struct CalendarItemView: View {
    let item: CalendarItem

    private var isClass: Bool { item.kind == .classOccurrence }
    private var isCancelled: Bool { isClass && item.isCancelled }

    var body: some View {
        let tint = item.color.color
        HStack(alignment: .top, spacing: Spacing.tiny) {
            mark(tint)
            content(tint)
            Spacer(minLength: 0)
        }
        .padding(Spacing.tiny)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tint.opacity(isClass ? 0.06 : 0.14), in: .rect(cornerRadius: Radius.small))
        // Opaque under the tint, so neither the hour lines nor the desktop
        // show through a block.
        .background(Palette.surface.color, in: .rect(cornerRadius: Radius.small))
        .overlay { if isClass { dashedBorder(tint) } }
        .clipShape(.rect(cornerRadius: Radius.small))
        .opacity(isCancelled ? 0.45 : 1)
        .help(isCancelled ? "\(item.title), cancelled" : item.title)
    }

    /// The leading edge: a class's book instead of a bar, since it has no
    /// colour of its own to wear (#207); a block's 3-pt colour bar otherwise.
    @ViewBuilder
    private func mark(_ tint: Color) -> some View {
        if isClass {
            Image(systemName: item.symbol ?? "book").font(TypeScale.caption).foregroundStyle(tint)
        } else {
            Capsule().fill(tint).frame(width: 3)
        }
    }

    /// The title with a block's own kind glyph beside it, and its time
    /// range under it once `item.showsTimeRange` says there is room.
    private func content(_ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Spacing.tiny) {
                if !isClass, let symbol = item.symbol {
                    Image(systemName: symbol).font(TypeScale.caption).foregroundStyle(tint)
                }
                Text(item.title).font(TypeScale.caption.weight(.medium)).foregroundStyle(Palette.ink.color)
                    .strikethrough(isCancelled)
            }
            if item.showsTimeRange {
                Text(item.timeRange).font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
            }
        }
    }

    private func dashedBorder(_ tint: Color) -> some View {
        RoundedRectangle(cornerRadius: Radius.small).strokeBorder(tint.opacity(0.5), style: .init(dash: [4, 3]))
    }
}

/// A slot being drawn on the empty grid (spec §9, #264): dashed in the
/// accent, like a plan not yet made, with the times it would take. It
/// follows the pointer live and never takes a click itself.
struct CalendarSlotGhostView: View {
    let item: CalendarItem

    var body: some View {
        Text(item.timeRange)
            .font(TypeScale.caption).monospacedDigit()
            .foregroundStyle(Palette.ink.color)
            .padding(Spacing.tiny)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Palette.accent.color.opacity(0.12), in: .rect(cornerRadius: Radius.small))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.small)
                    .strokeBorder(Palette.accent.color, style: .init(lineWidth: 1, dash: [4, 3]))
            }
            .allowsHitTesting(false)
            .accessibilityLabel("New slot, \(item.timeRange)")
    }
}

/// A focus session that ran: a thin rounded lane at the column's trailing
/// edge, in ink, because what happened is not a signal (R8).
struct CalendarSessionView: View {
    let item: CalendarItem

    var body: some View {
        RoundedRectangle(cornerRadius: CalendarLayout.sessionLaneWidth / 2)
            .fill(Palette.ink.color.opacity(0.3))
            .help(item.title)
    }
}

/// Now: a shu dot and line across today's column, shu's one place on Plan.
struct CalendarNowMarkView: View {
    static let dot: CGFloat = 7

    var body: some View {
        HStack(spacing: 0) {
            Circle().fill(Palette.shu.color).frame(width: Self.dot, height: Self.dot)
            Rectangle().fill(Palette.shu.color).frame(height: 1.5)
        }
        .accessibilityLabel("Now")
    }
}
