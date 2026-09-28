import Foundation
import OmakaseFeatures
import UserNotifications

/// The phase-end notification (spec: UserNotifications for pomodoro
/// transitions). One pending request at a time: a new end replaces it, and
/// pause or skip cancels it. Permission is asked the first time a phase starts.
@MainActor
final class PhaseNotifier {
    private static let identifier = "omakase.phase-end"
    private let center = UNUserNotificationCenter.current()

    func notify(at date: Date?, ending phase: TimerPhase) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        guard let date else { return }
        let notice = PhaseNotice.ending(phase)
        let center = self.center
        Task {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            let content = UNMutableNotificationContent()
            (content.title, content.body, content.sound) = (notice.title, notice.body, .default)
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
            try? await center.add(
                UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger))
        }
    }
}
