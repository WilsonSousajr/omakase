import SwiftUI

/// M2 mockup: sign-in. The tracked wordmark and the web's tagline as a
/// section label, one prominent shu action. #103 moves this look into
/// `SignInView`.
struct SignInMockupView: View {
    var body: some View {
        VStack(spacing: Spacing.xLarge) {
            VStack(spacing: Spacing.small) {
                Text("OMAKASE")
                    .font(TypeScale.display)
                    .tracking(TypeScale.displayTracking)
                    .foregroundStyle(Palette.ink.color)
                Text("Plan. Focus. Ship.").sectionLabel()
            }
            Button("Sign in with Google") {}
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(Palette.shu.color)
        }
        .frame(width: 520, height: 420)
        .background(Palette.background.color)
    }
}

#Preview("Sign-in, light") { SignInMockupView().preferredColorScheme(.light) }
#Preview("Sign-in, dark") { SignInMockupView().preferredColorScheme(.dark) }
