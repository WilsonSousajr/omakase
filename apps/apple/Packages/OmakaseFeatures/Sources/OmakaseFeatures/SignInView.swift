import SwiftUI

/// Sign-in: the tracked wordmark, the web's tagline as a section label, and
/// the one primary action as an ink pill (docs/design-system-apple.md).
public struct SignInView: View {
    @Bindable private var model: SignInModel
    public init(model: SignInModel) { self.model = model }

    public var body: some View {
        VStack(spacing: Spacing.xLarge) {
            VStack(spacing: Spacing.small) {
                Text("OMAKASE")
                    .font(TypeScale.display)
                    .tracking(TypeScale.displayTracking)
                    .foregroundStyle(Palette.ink.color)
                Text("Plan. Focus. Ship.").sectionLabel()
            }
            Button("Sign in with Google") { Task { await model.signIn() } }
                .buttonStyle(.primary)
                .disabled(model.state == .working)
            if case .failed(let message) = model.state {
                Text(message).font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
            }
        }
        .padding(Spacing.xxLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
