import OmakaseAPI
import OmakaseFeatures
import SwiftUI

@main
struct OmakaseMacApp: App {
    @State private var services = Self.makeServices()
    @State private var signIn: SignInModel?
    @State private var signedIn = false

    var body: some Scene {
        WindowGroup("Omakase") {
            content
                .frame(minWidth: 520, minHeight: 420)
                .task { await start() }
        }
        .modelContainer(services.container)
    }

    @ViewBuilder private var content: some View {
        if signedIn {
            NavigationStack {
                TodayView(day: APIDay.today().string) { try? services.writes.toggleCompletion($0) }
            }
        } else if let signIn {
            SignInView(model: signIn).onChange(of: signIn.state) { _, state in
                guard case .signedIn = state else { return }
                signedIn = true
                Task { await services.catchUp() }
            }
        }
    }

    private func start() async {
        let api = services.api
        signIn = SignInModel(
            authenticator: WebAuthenticator(clientID: services.googleClientID),
            signIn: { try await api.signIn(googleIDToken: $0).email })
        signedIn = (try? await api.me()) != nil
        services.startBackgroundCatchUp()
    }

    /// The store and API are the app's foundation; without them there is no app to show.
    private static func makeServices() -> AppServices {
        do {
            return try AppServices()
        } catch {
            fatalError("Omakase could not open its local store: \(error)")
        }
    }
}
