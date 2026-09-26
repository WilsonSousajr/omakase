import OmakaseAPI
import OmakaseFeatures
import OmakaseStore
import SwiftUI

@main
struct OmakaseMacApp: App {
    @State private var services = Self.makeServices()
    @State private var signIn: SignInModel?
    @State private var signedIn = false
    @State private var section: SidebarItem? = .focus

    var body: some Scene {
        WindowGroup("Omakase") {
            content
                .frame(minWidth: WindowSize.minimum.width, minHeight: WindowSize.minimum.height)
                // Dark first, grey accent, translucent ground (docs/design-system-apple.md).
                .preferredColorScheme(Appearance.default.colorScheme)
                .tint(Palette.accent.color)
                .omakaseWindowBackground()
                .task { await start() }
        }
        .modelContainer(services.container)
    }

    @ViewBuilder private var content: some View {
        if signedIn {
            NavigationSplitView {
                List(SidebarItem.allCases, selection: $section) { Label($0.title, systemImage: $0.symbol) }
            } detail: {
                today
            }
        } else if let signIn {
            SignInView(model: signIn).onChange(of: signIn.state) { _, state in
                guard case .signedIn = state else { return }
                signedIn = true
                Task { handle(await services.coordinator.catchUp()) }
            }
        }
    }

    private var today: some View {
        TodayView(day: APIDay.today().string) { record in
            Task {
                handle(
                    (try? await services.coordinator.write { try services.writes.toggleCompletion(record) })
                        ?? .synced)
            }
        }
    }

    private func start() async {
        let api = services.api
        signIn = SignInModel(
            authenticator: WebAuthenticator(clientID: services.googleClientID),
            signIn: { try await api.signIn(googleIDToken: $0).email })
        // Stored tokens decide, not a network call: offline, the cached Today
        // still shows (final review C1). The server says otherwise via handle().
        signedIn = await api.hasStoredSession()
        services.startBackgroundCatchUp { handle($0) }
    }

    /// Only a definite sign-out leaves Today; an offline failure keeps the cache (review I3).
    private func handle(_ outcome: SyncCoordinator.Outcome) {
        if outcome == .signedOut { signedIn = false }
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
