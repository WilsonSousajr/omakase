import Foundation
import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// Settings (#228): a draft of the profile, saved online after a pause as
/// only what changed; a refusal puts the draft back and says why.
@MainActor
struct SettingsModelTests {
    final class Recorder {
        var saved: [ProfileChange] = []
        var failure: Error?
        var loginItem = false
        var loginFailure: Error?
    }

    struct Refused: Error, CustomStringConvertible { var description: String { "Needs a connection." } }

    private let recorder = Recorder()
    private let base = ProfileValues(
        workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, beforeLongBreak: 4, workGoalHours: 8,
        studyGoalHours: 4, blockReminderMinutes: 5, shutdownReminderTime: nil, weekStartsOn: "monday",
        timezone: "America/Sao_Paulo")

    private func model() -> SettingsModel {
        let recorder = recorder
        let settings = SettingsModel(
            actions: .init(
                save: { change in
                    if let failure = recorder.failure { throw failure }
                    recorder.saved.append(change)
                },
                loginItemEnabled: { recorder.loginItem },
                setLoginItem: { enabled in
                    if let failure = recorder.loginFailure { throw failure }
                    recorder.loginItem = enabled
                }),
            schedule: { _ in })
        settings.load(base)
        return settings
    }

    @Test func onlyWhatChangedIsSaved() async {
        let settings = model()
        settings.draft?.workMinutes = 50
        settings.draft?.workGoalHours = 6.5
        settings.changed()
        #expect(recorder.saved.isEmpty)
        await settings.flush()
        #expect(recorder.saved == [ProfileChange(workMinutes: 50, workGoalHours: 6.5)])
    }

    @Test func turningTheHeadsUpOffClearsIt() async {
        let settings = model()
        settings.draft?.blockReminderMinutes = nil
        settings.changed()
        await settings.flush()
        #expect(recorder.saved == [ProfileChange(blockReminderMinutes: .clear)])
    }

    @Test func aShutdownTimeIsSet() async {
        let settings = model()
        settings.draft?.shutdownReminderTime = "21:30:00"
        settings.changed()
        await settings.flush()
        #expect(recorder.saved == [ProfileChange(shutdownReminderTime: .set("21:30:00"))])
    }

    @Test func nothingChangedSavesNothing() async {
        let settings = model()
        settings.changed()
        await settings.flush()
        #expect(recorder.saved.isEmpty)
    }

    @Test func aRefusalPutsTheDraftBackAndSaysWhy() async {
        recorder.failure = Refused()
        let settings = model()
        settings.draft?.workMinutes = 50
        settings.changed()
        await settings.flush()
        #expect(settings.draft == base && settings.message == "Needs a connection.")
    }

    @Test func aSavedDraftIsTheNewBaseline() async {
        let settings = model()
        settings.draft?.workMinutes = 50
        settings.changed()
        await settings.flush()
        settings.draft?.shortBreakMinutes = 10
        settings.changed()
        await settings.flush()
        #expect(recorder.saved.last == ProfileChange(shortBreakMinutes: 10))
    }

    @Test func theStoresCopyDoesNotOverwriteAnEditWaitingToSave() {
        let settings = model()
        settings.draft?.workMinutes = 50
        settings.changed()
        settings.load(base)
        #expect(settings.draft?.workMinutes == 50)
    }

    @Test func launchAtLoginFollowsTheSystemAndSaysWhenItCannot() {
        let settings = model()
        #expect(!settings.launchesAtLogin)
        settings.setLaunchesAtLogin(true)
        #expect(settings.launchesAtLogin && recorder.loginItem)
        recorder.loginFailure = Refused()
        settings.setLaunchesAtLogin(false)
        #expect(settings.launchesAtLogin && settings.message == "Needs a connection.")
    }
}
