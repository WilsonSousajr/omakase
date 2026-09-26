import SwiftUI

/// M2 mockup: Plan, as the web client had it. Today's tasks on the left (with
/// "Plan my day"), the calendar on the right for time blocking: drag a task
/// onto a slot. Content is opaque; blocks are tinted by their source.
struct PlanMockupView: View {
    var body: some View {
        HStack(spacing: 0) {
            PlanTaskColumnView().frame(width: 380)
            Divider().overlay(Palette.hairline.color)
            PlanCalendarView()
        }
        .background(Palette.background.color)
    }
}

struct PlanTaskColumnView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Tasks").sectionLabel()
                Spacer()
                Button("Plan my day") {}.buttonStyle(.glass).controlSize(.small)
            }
            .padding(Spacing.large)
            Divider().overlay(Palette.hairline.color)
            VStack(alignment: .leading, spacing: Spacing.small) {
                ForEach(MockupDay.toDo + MockupDay.inProgress) { item in
                    TaskRowView(title: item.title, priority: item.priority, minutes: item.minutes, isCompleted: false)
                        .padding(.horizontal, Spacing.medium)
                        .padding(.vertical, Spacing.tiny)
                        .background(Palette.surface.color, in: .rect(cornerRadius: Radius.medium))
                }
            }
            .padding(Spacing.large)
            Spacer()
        }
    }
}

struct PlanCalendarView: View {
    @State private var range = "Day"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.medium) {
                Text("Thursday, 25 September").font(TypeScale.title).foregroundStyle(Palette.ink.color)
                Spacer()
                Button("Today") {}.buttonStyle(.glass)
                Picker("Range", selection: $range) {
                    Text("Day").tag("Day")
                    Text("Week").tag("Week")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 140)
            }
            .padding(Spacing.large)
            Divider().overlay(Palette.hairline.color)
            CalendarDayGridView().padding(.top, Spacing.medium)
        }
    }
}

/// The hour grid, 08:00 to 19:00, with blocks laid over it by start and length.
struct CalendarDayGridView: View {
    static let firstHour = 8.0
    static let hourHeight: CGFloat = 52
    static let gutter: CGFloat = 56

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(8..<19, id: \.self) { CalendarHourRowView(hour: $0, height: Self.hourHeight) }
            }
            ForEach(MockupDay.blocks) { block in
                CalendarBlockView(block: block)
                    .frame(height: CGFloat(block.hours) * Self.hourHeight - 2)
                    .padding(.leading, Self.gutter)
                    .padding(.trailing, Spacing.large)
                    .offset(y: y(block.start) + 1)
            }
            NowLineView()
                .padding(.leading, Self.gutter - Spacing.tiny)
                .offset(y: y(MockupDay.now) - 3)
        }
    }

    private func y(_ hour: Double) -> CGFloat { CGFloat(hour - Self.firstHour) * Self.hourHeight }
}

/// The current time: a shu dot and line across the day.
struct NowLineView: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle().fill(Palette.shu.color).frame(width: 7, height: 7)
            Rectangle().fill(Palette.shu.color).frame(height: 1.5)
        }
    }
}

struct CalendarHourRowView: View {
    let hour: Int
    let height: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.small) {
            Text(String(format: "%02d:00", hour))
                .font(TypeScale.caption).monospacedDigit()
                .foregroundStyle(Palette.inkMuted.color)
                .frame(width: CalendarDayGridView.gutter - Spacing.small, alignment: .trailing)
                .offset(y: -6)
            VStack {
                Divider().overlay(Palette.hairline.color)
                Spacer()
            }
        }
        .frame(height: height)
    }
}

/// A time block as the web drew it: a source-colour bar and a faint fill.
/// A class occurrence is dashed instead, because it is fixed, not planned.
struct CalendarBlockView: View {
    let block: MockupDay.Block

    var body: some View {
        let tint = block.source.color
        HStack(alignment: .top, spacing: Spacing.small) {
            if !block.isClass { Capsule().fill(tint).frame(width: 3) }
            if block.isClass { Image(systemName: "book").foregroundStyle(tint) }
            Text(block.title).font(TypeScale.caption.weight(.medium)).foregroundStyle(Palette.ink.color)
            Spacer()
        }
        .padding(Spacing.small)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tint.opacity(block.isClass ? 0.06 : 0.14), in: .rect(cornerRadius: Radius.small))
        // Opaque under the tint, so the hour lines do not show through a block.
        .background(Palette.background.color, in: .rect(cornerRadius: Radius.small))
        .overlay {
            if block.isClass {
                RoundedRectangle(cornerRadius: Radius.small).strokeBorder(
                    tint.opacity(0.5), style: .init(dash: [4, 3]))
            }
        }
    }
}

#Preview("Plan, light") { PlanMockupView().frame(width: 1120, height: 680).preferredColorScheme(.light) }
#Preview("Plan, dark") { PlanMockupView().frame(width: 1120, height: 680).preferredColorScheme(.dark) }
