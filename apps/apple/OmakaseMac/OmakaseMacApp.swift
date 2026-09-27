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
    @State private var review: ReviewModel?
    @State private var plan: PlanModel?
    @State private var inbox: InboxModel?
    @State private var projects: ProjectsModel?
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
            NavigationSplitView {
                List(SidebarItem.allCases, selection: $section) { item in
                    SidebarRowView(item: item).listItemTint(.fixed(AppTint.sidebarIcons.color))
                }
                .scrollContentBackground(.hidden)
            } detail: {
                detail
            }
            .toolbar {
                if let failedWrites {
                    ToolbarItem(placement: .primaryAction) { SyncIndicatorView(model: failedWrites) }
                }
            }
        } else if let signIn {
            SignInView(model: signIn).onChange(of: signIn.state) { _, state in
                guard case .signedIn = state else { return }
                signedIn = true
                Task { handle(await services.coordinator.catchUp()) }
            }
        }
    }

    @ViewBuilder private var detail: some View {
        switch section {
        // Plan's panel acts through Focus's model, so its Complete, Reschedule,
        // Remind me and the editor's Save queue exactly as Focus's do (#217, #218).
        case .plan:
            if let plan, let focus {
                PlanScreenView(day: day, model: plan, focus: focus, overlay: calendarOverlay)
            }
        case .review: if let review { ReviewView(day: day, model: review) }
        case .inbox: if let inbox { InboxView(day: day, model: inbox) }
        case .projects: if let projects { ProjectsView(model: projects) }
        case .focus, nil: if let focus, let timer { FocusView(day: day, model: focus, timer: timer) }
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
        review = ReviewModel(actions: services.reviewActions { handle($0) })
        settings = SettingsModel(actions: services.settingsActions())
        inbox = InboxModel(actions: services.inboxActions { handle($0) }) { FocusDay().today }
        projects = ProjectsModel(actions: services.projectsActions())
        plan = PlanModel(actions: services.planActions { handle($0) }) { FocusDay().today }
        calendarOverlay = services.makeCalendarOverlay()
        let timer = services.makeTimer { handle($0) }
        self.timer = timer
        services.startTicking(timer)
        startSyncIndicator()
        capture = GlobalCapture { [services] title, destination in
            services.capture(title, to: destination) { handle($0) }
        }
        signedIn = await api.hasStoredSession()
        services.startBackgroundCatchUp(onPathChange: { failedWrites?.setPathOnline($0) }, onOutcome: { handle($0) })
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
        guard section == .plan, let plan, let calendarOverlay else { return }
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
