import OmakaseAPI
import OmakaseFeatures
import OmakaseStore
import SwiftUI

@main
struct OmakaseMacApp: App {
    @State private var services = Self.makeServices()
    @State private var signIn: SignInModel?
    @State private var signedIn = false
    @State private var focus: FocusModel?
    @State private var review: ReviewModel?
    @State private var plan: PlanModel?
    @State private var inbox: InboxModel?
    @State private var projects: ProjectsModel?
    @State private var study: StudyModel?
    @State private var calendarOverlay: CalendarOverlayModel?
    @State private var timer: TimerModel?
    @State private var failedWrites: FailedWritesModel?
    @State private var prompt: SessionPrompt?
    @State private var capture: GlobalCapture?
    @State private var settings: SettingsModel?
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
                .tint(AppTint.window.color)
                .omakaseWindowBackground()
                .task { await start() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { day = FocusDay().today } }
                .onChange(of: signedIn) { _, isSignedIn in capture?.setEnabled(isSignedIn) }
                .onChange(of: timer?.lastFinished) { _, finished in prompt = services.prompt(for: finished) }
                .sheet(
                    item: $prompt, onDismiss: { timer?.dismissFinished() },
                    content: { prompt in SessionPromptView(prompt: prompt) { services.apply($0) { handle($0) } } }
                )
        }
        .modelContainer(services.container)
        .commands { CaptureCommands(capture: capture, isEnabled: signedIn) }

        // ⌘, (#228): signed out, there is no profile to edit.
        Settings {
            if signedIn, let settings {
                SettingsView(model: settings, overlay: calendarOverlay, account: settingsAccount)
                    .modelContainer(services.container)
            }
        }

        // The running timer from anywhere (spec, Menu bar): its countdown is
        // the status item's label while a phase is on.
        MenuBarExtra {
            if let timer, let focus {
                MenuBarTimerPanelView(day: day, timer: timer) { id in
                    focus.selectedID = id
                    NSApp.activate()
                }
                .tint(AppTint.menuBarPanel.color)
                .modelContainer(services.container)
            }
        } label: {
            if let timer, let text = MenuBar.label(for: timer.state, remaining: timer.remainingText) {
                Label(text, systemImage: "timer")
            } else {
                Image(systemName: "timer")
            }
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder private var content: some View {
        if signedIn {
            MainWindowView(day: day, models: screenModels) { capture?.show(context: $0) }
        } else if let signIn {
            SignInView(model: signIn).onChange(of: signIn.state) { _, state in
                guard case .signedIn = state else { return }
                signedIn = true
                Task { handle(await services.coordinator.catchUp()) }
            }
        }
    }

    /// Bundled for `MainWindowView` (#256); every model here is nil until
    /// `makeScreenModels()` wires it in `start()`.
    private var screenModels: ScreenModels {
        ScreenModels(
            focus: focus, review: review, plan: plan, inbox: inbox, projects: projects, study: study,
            calendarOverlay: calendarOverlay, timer: timer, failedWrites: failedWrites)
    }

    private func start() async {
        let api = services.api
        signIn = SignInModel(
            authenticator: WebAuthenticator(clientID: services.googleClientID),
            signIn: { try await api.signIn(googleIDToken: $0).email })
        // Stored tokens decide, not a network call: offline, the cached Today
        // still shows (final review C1). The server says otherwise via handle().
        makeScreenModels()
        let timer = services.makeTimer { handle($0) }
        self.timer = timer
        services.startTicking(timer)
        startSyncIndicator()
        capture = GlobalCapture(
            actions: services.captureActions { handle($0) }, directory: { [services] in services.capturePlaces() },
            lastArea: { [services] in services.lastCaptureArea() })
        signedIn = await api.hasStoredSession()
        services.startBackgroundCatchUp(onPathChange: { failedWrites?.setPathOnline($0) }, onOutcome: { handle($0) })
    }

    /// One model per screen, each acting through the services' writes.
    private func makeScreenModels() {
        focus = FocusModel(actions: services.focusActions { handle($0) })
        review = ReviewModel(actions: services.reviewActions { handle($0) })
        settings = SettingsModel(actions: services.settingsActions())
        inbox = InboxModel(actions: services.inboxActions { handle($0) }) { FocusDay().today }
        projects = ProjectsModel(actions: services.projectsActions())
        study = StudyModel(actions: services.studyActions())
        // A drawn slot opens the same panel as ⌘N (#264); `capture` is read when it fires.
        let planActions = services.planActions(openCapture: { capture?.show(context: $0) }, onOutcome: { handle($0) })
        plan = PlanModel(actions: planActions) { FocusDay().today }
        calendarOverlay = services.makeCalendarOverlay()
    }

    /// The toolbar's sync item follows every catch-up, the backoff wake's
    /// included, rather than polling the outbox (#185).
    private func startSyncIndicator() {
        let model = FailedWritesModel(actions: services.failedWritesActions())
        services.coordinator.onEveryOutcome = { model.record($0) }
        model.refresh()
        failedWrites = model
    }

    /// Only a definite sign-out leaves Today; an offline failure keeps the cache (review I3).
    /// Plan, while it shows, reads its visible days again (#203), Calendar.app's included (#229).
    private func handle(_ outcome: SyncCoordinator.Outcome) {
        if outcome == .signedOut { signedIn = false }
        if outcome == .synced { Task { await services.refreshLibrary() } }
        services.replanReminders()
        plan?.caughtUp()
        guard let plan, plan.isShowing, let calendarOverlay else { return }
        Task { await calendarOverlay.refresh(days: plan.visibleDays) }
    }

    private var settingsAccount: SettingsAccount {
        SettingsAccount(unsentCount: { services.unsentCount() }, signOut: { Task { await signOut() } })
    }

    /// Signed out, the next account starts clean: nothing of this one stays (#224).
    private func signOut() async {
        await services.signOut()
        signedIn = false
        failedWrites?.refresh()
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
