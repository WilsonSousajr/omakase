import Foundation
import Observation
import OmakaseStore

/// Settings (#228): a draft of the profile, saved online a moment after the
/// last change as only what changed. A refusal puts the draft back to the
/// saved copy and says why, so the screen never shows a value the server
/// does not have. Launch at login is the system's, read and set directly.
///
///     let settings = SettingsModel(actions: actions)
///     settings.load(ProfileValues(record: profile))
///     settings.draft.workMinutes = 50; settings.changed()
@Observable
@MainActor
public final class SettingsModel {
    public typealias Scheduler = ReviewModel.Scheduler

    public struct Actions {
        let save: (ProfileChange) async throws -> Void
        let loginItemEnabled: () -> Bool
        let setLoginItem: (Bool) throws -> Void
        /// The signed-in email, read online; nil offline.
        let account: () async -> String?

        public init(
            save: @escaping (ProfileChange) async throws -> Void, loginItemEnabled: @escaping () -> Bool,
            setLoginItem: @escaping (Bool) throws -> Void, account: @escaping () async -> String? = { nil }
        ) {
            (self.save, self.loginItemEnabled, self.setLoginItem) = (save, loginItemEnabled, setLoginItem)
            self.account = account
        }
    }

    public var draft: ProfileValues?
    /// The last refusal or failure, in words; cleared by the next success.
    public private(set) var message: String?
    public private(set) var launchesAtLogin: Bool
    public private(set) var email: String?

    @ObservationIgnored private var saved: ProfileValues?
    @ObservationIgnored private var isPending = false
    @ObservationIgnored private let actions: Actions
    @ObservationIgnored private let schedule: Scheduler

    public init(actions: Actions, schedule: @escaping Scheduler = ReviewModel.afterPause(.milliseconds(700))) {
        (self.actions, self.schedule) = (actions, schedule)
        launchesAtLogin = actions.loginItemEnabled()
    }

    /// The store's copy; it never overwrites an edit still waiting to save.
    public func load(_ values: ProfileValues) {
        saved = values
        guard !isPending else { return }
        draft = values
    }

    /// Call after editing `draft`: the save goes after a pause.
    public func changed() {
        isPending = true
        schedule { [weak self] in Task { await self?.flush() } }
    }

    public func flush() async {
        guard isPending, let draft, let saved else { return }
        isPending = false
        let change = draft.change(from: saved)
        guard !change.isEmpty else { return }
        do {
            try await actions.save(change)
            (self.saved, message) = (draft, nil)
        } catch {
            (self.draft, message) = (saved, String(describing: error))
        }
    }

    /// Reads the signed-in address. An offline read (nil) keeps the last
    /// known one: the sidebar's footer reads it each time it appears (#260),
    /// and a known address shouldn't turn back into "Account" offline.
    public func loadAccount() async { email = await actions.account() ?? email }

    public func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            try actions.setLoginItem(enabled)
            (launchesAtLogin, message) = (enabled, nil)
        } catch {
            message = String(describing: error)
        }
    }
}
