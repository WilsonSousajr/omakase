import SwiftUI

/// The hours as a grid: a time gutter, then a column per visible day, each
/// with its hour lines, Calendar.app's events and classes behind (#229),
/// blocks in lanes, sessions at the trailing edge, and the now line on
/// today's column. Opens at `CalendarLayout.initialMinutes`, on appear and
/// whenever the range moves (spec M4, Grid; #215). Each column takes drops
/// (#203).
struct CalendarGridView: View {
    static let gutter: CGFloat = 56

    let model: PlanModel
    let items: [CalendarItem]
    let layout = CalendarLayout.standard
    /// Scrolled by points, not to an hour's id: the hour lines' ForEach
    /// shares the gutter's Int ids at offset zero, so `scrollTo(8)` could
    /// land on 06:00, and it ran once, before layout (#215).
    @State private var position = ScrollPosition()

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = model.now(at: context.date)
            VStack(spacing: 0) {
                if model.mode == .week {
                    CalendarDayHeadersView(model: model, today: now.day)
                    Divider().overlay(Palette.hairline.color)
                }
                scrolledHours(now: now)
            }
        }
    }

    private func scrolledHours(now: CalendarNow) -> some View {
        let lanes = CalendarLayout.lanes(for: items)
        return ScrollView {
            HStack(alignment: .top, spacing: 0) {
                CalendarTimeGutterView(layout: layout)
                ForEach(model.visibleDays, id: \.self) { day in
                    CalendarDayColumnView(
                        day: day, model: model, items: items, lanes: lanes, layout: layout,
                        now: day == now.day ? now : nil)
                }
            }
            .padding(.vertical, Spacing.medium)
        }
        .scrollPosition($position)
        // A task runs after the first layout, so the offset lands; keyed by
        // the range, so Today, ‹ › and Day/Week scroll again (#215).
        .task(id: "\(model.mode.rawValue) \(model.anchorDay)") { scrollToOpening(now: now) }
    }

    private func scrollToOpening(now: CalendarNow) {
        let day = model.visibleDays.contains(now.day) ? now.day : model.anchorDay
        let minutes = layout.initialMinutes(day: day, today: now.day, nowMinutes: now.minutes)
        position.scrollTo(y: layout.offset(forMinutes: minutes))
    }
}

/// The week's column headers, "Mon 21", with today's in ink.
struct CalendarDayHeadersView: View {
    let model: PlanModel
    let today: String

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: CalendarGridView.gutter, height: 1)
            ForEach(model.visibleDays, id: \.self) { day in
                Text(model.dayHeader(day))
                    .font(day == today ? TypeScale.caption.weight(.semibold) : TypeScale.caption)
                    .foregroundStyle((day == today ? Palette.ink : Palette.inkMuted).color)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, Spacing.small)
    }
}

/// "08:00" beside each hour line.
struct CalendarTimeGutterView: View {
    static let labelWidth = CalendarGridView.gutter - Spacing.small

    let layout: CalendarLayout

    var body: some View {
        VStack(spacing: 0) {
            ForEach(layout.hours, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(TypeScale.caption).monospacedDigit()
                    .foregroundStyle(Palette.inkMuted.color)
                    .offset(y: -6)
                    .frame(width: Self.labelWidth, height: layout.hourHeight, alignment: .topTrailing)
                    .padding(.trailing, Spacing.small)
            }
        }
    }
}

/// One day: hour lines, then its items placed by `CalendarLayout`. A drop
/// lands at its y, snapped by `PlanDrop` (#203).
struct CalendarDayColumnView: View {
    /// The column's own space, so a drop's and a resize's y are grid offsets.
    static let space = "plan.column"

    let day: String
    let model: PlanModel
    /// Every visible item: a block dropped here may come from another day.
    let items: [CalendarItem]
    let lanes: [String: CalendarLane]
    let layout: CalendarLayout
    /// Set on today's column only.
    let now: CalendarNow?
    /// The block whose bottom edge is being dragged, at its previewed end.
    @State private var resizing: CalendarItem?
    @State private var isTargeted = false

    /// Today's own column is lifted with a faint fill (spec §9); `now` is
    /// only ever set on the column that is today (`CalendarGridView.body`).
    private var isToday: Bool { now != nil }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .topLeading) {
                // The empty grid under everything: a click there closes the panel (#217).
                CalendarHourLinesView(layout: layout)
                    .contentShape(.rect)
                    .onTapGesture { model.select(nil) }
                ForEach(ofKind(.externalEvent)) { item in
                    placed(item, CalendarLayout.blockSpan(lane: nil, width: width)) {
                        CalendarExternalEventView(item: item)
                    }
                }
                ForEach(ofKind(.classOccurrence)) { item in
                    placed(item, CalendarLayout.blockSpan(lane: nil, width: width)) { classView(item) }
                }
                blocks(width: width)
                ForEach(ofKind(.focusSession)) { item in
                    placed(item, CalendarLayout.sessionSpan(width: width)) { CalendarSessionView(item: item) }
                }
                nowMark
            }
        }
        .coordinateSpace(.named(Self.space))
        .frame(height: layout.totalHeight)
        .background(Palette.surface.color.opacity(isTargeted ? 0.35 : (isToday ? 0.06 : 0)))
        .dropDestination(for: String.self) { texts, location in
            texts.first.map { model.drop($0, day: day, offset: location.y, items: items) } ?? false
        } isTargeted: {
            isTargeted = $0
        }
        .overlay(alignment: .leading) { Rectangle().fill(Palette.hairline.color).frame(width: 1) }
    }

    private func blocks(width: CGFloat) -> some View {
        ForEach(ofKind(.block)) { item in
            placed(
                resizing?.id == item.id ? resizing ?? item : item,
                CalendarLayout.blockSpan(lane: lanes[item.id], width: width)
            ) {
                PlanBlockView(item: item, model: model, items: items, layout: layout, resizing: $resizing)
            }
        }
    }

    /// A class is cancelled on its date, or restored, from its menu (#207).
    private func classView(_ item: CalendarItem) -> some View {
        CalendarItemView(item: item)
            .contextMenu {
                Button(item.cancellationMenuTitle, systemImage: item.isCancelled ? "arrow.uturn.backward" : "xmark") {
                    model.toggleCancellation(item)
                }
            }
    }

    private func ofKind(_ kind: CalendarItem.Kind) -> [CalendarItem] {
        items.filter { $0.day == day && $0.kind == kind }
    }

    @ViewBuilder
    private func placed(_ item: CalendarItem, _ span: CalendarSpan, content: () -> some View) -> some View {
        if let band = layout.band(for: item) {
            content()
                .frame(width: span.width, height: band.height)
                .offset(x: span.leading, y: band.top)
        }
    }

    @ViewBuilder private var nowMark: some View {
        if let now {
            let top = layout.offset(forMinutes: now.minutes)
            if top >= 0, top <= layout.totalHeight {
                CalendarNowMarkView().offset(x: -CalendarNowMarkView.dot / 2, y: top - CalendarNowMarkView.dot / 2)
            }
        }
    }
}

/// A hairline at the top of every hour, and one closing the last.
struct CalendarHourLinesView: View {
    let layout: CalendarLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.hours + [layout.lastHour], id: \.self) { hour in
                Rectangle()
                    .fill(Palette.hairline.color)
                    .frame(height: 1)
                    .offset(y: layout.offset(forMinutes: hour * 60))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
