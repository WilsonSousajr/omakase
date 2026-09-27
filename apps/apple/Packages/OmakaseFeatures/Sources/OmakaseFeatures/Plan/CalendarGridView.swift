import SwiftUI

/// The hours as a grid: a time gutter, then a column per visible day, each
/// with its hour lines, Calendar.app's events and classes behind (#229), blocks in lanes, sessions at the
/// trailing edge, and the now line on today's column. Scrolled to 08:00 on
/// appear (spec M4, Grid). Each column takes drops (#203).
struct CalendarGridView: View {
    static let gutter: CGFloat = 56
    static let openingHour = 8

    let model: PlanModel
    let items: [CalendarItem]
    let layout = CalendarLayout.standard

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
        return ScrollViewReader { proxy in
            ScrollView {
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
            .onAppear { proxy.scrollTo(Self.openingHour, anchor: .top) }
        }
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

/// "08:00" beside each hour line; each hour is a scroll anchor.
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
                    .id(hour)
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

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .topLeading) {
                CalendarHourLinesView(layout: layout)
                ForEach(ofKind(.externalEvent)) { item in
                    placed(item, CalendarLayout.blockSpan(lane: nil, width: width)) {
                        CalendarExternalEventView(item: item)
                    }
                }
                ForEach(ofKind(.classOccurrence)) { item in
                    placed(item, CalendarLayout.blockSpan(lane: nil, width: width)) { CalendarItemView(item: item) }
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
        .background(Palette.surface.color.opacity(isTargeted ? 0.35 : 0))
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
