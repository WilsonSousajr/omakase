import SwiftUI

/// The workload check beside the day in the Focus header (#177): muted ink
/// while the plan fits the goal, ink with a warning symbol once it is over.
/// Monochrome: shu is kept for the focus phase and the now line.
struct WorkloadBannerView: View {
    let warning: WorkloadWarning

    var body: some View {
        if let text = warning.text {
            if warning.isOver {
                Label(text, systemImage: "exclamationmark.triangle")
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.ink.color)
            } else {
                Text(text)
                    .font(TypeScale.caption)
                    .foregroundStyle(Palette.inkMuted.color)
            }
        }
    }
}
