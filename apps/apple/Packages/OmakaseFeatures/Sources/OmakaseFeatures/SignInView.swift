import SwiftUI

/// M1's sign-in screen. The M2 identity pass owns its look.
public struct SignInView: View {
    @Bindable private var model: SignInModel
    public init(model: SignInModel) { self.model = model }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Omakase").font(.largeTitle.bold())
            Button("Sign in with Google") { Task { await model.signIn() } }
                .buttonStyle(.glassProminent)
                .disabled(model.state == .working)
            if case .failed(let message) = model.state { Text(message).foregroundStyle(.secondary) }
        }
        .padding(40)
    }
}
