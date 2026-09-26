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
    @State private var focus: FocusModel?
    @State private var timer: TimerModel?
    @State private var prompt: SessionPrompt?
    /// Recomputed when the app becomes active: a window left open overnight
    /// moves to the new day (M1's known limitation).
    @State private var day = FocusDay().today
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup("Omakase") {
            content
                .frame(minWidth: WindowSize.minimum.width, minHeight: WindowSize.minimum.height)
                // Dark first, grey accent, translucent ground (docs/design-system-apple.md).
                .preferredColorScheme(Appearance.default.colorScheme)
                .tint(Palette.accent.color)
                .omakaseWindowBackground()
                .task { await start() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { day = FocusDay().today } }
                .onChange(of: timer?.lastFinished) { _, finished in prompt = services.prompt(for: finished) }
                .sheet(
                    item: $prompt, onDismiss: { timer?.dismissFinished() },
                    content: { prompt in SessionPromptView(prompt: prompt) { services.apply($0) { handle($0) } } })
        }
        .modelContainer(services.container)
    }

    @ViewBuilder private var content: some View {
        if signedIn {
            NavigationSplitView {
                List(SidebarItem.allCases, selection: $section) { Label($0.title, systemImage: $0.symbol) }
            } detail: {
                if let focus, let timer { FocusView(day: day, model: focus, timer: timer) }
            }
        } else if let signIn {
            SignInView(model: signIn).onChange(of: signIn.state) { _, state in
                guard case .signedIn = state else { return }
                signedIn = true
                Task { handle(await services.coordinator.catchUp()) }
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
        focus = FocusModel(actions: services.focusActions { handle($0) })
        let timer = services.makeTimer { handle($0) }
        self.timer = timer
        services.startTicking(timer)
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
