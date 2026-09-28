import Foundation
import Observation
import OmakaseStore

/// The day's review draft: rating, energy and win, each change saved after a
/// short pause so typing is one write and quitting halfway loses nothing
/// (M3.4 spec, Decisions). The write and the pause are injected, so the app
/// wires the outbox and tests hold the pause.
///
/// Each unfinished task also has a rollover choice, tomorrow unless changed
/// (IDEA §8.2); Shut down sends the draft and every choice as one write (#179).
///
///     let model = ReviewModel(actions: .init(save: { day, values in … }, shutDown: { day, values, moves in … }))
///     model.load(day: "2026-03-07", values: ReviewValues(record: stored))
///     model.chooseRating(4)
///     model.shutDown(unfinished: summary.unfinished.map(\.id))
@Observable
@MainActor
public final class ReviewModel {
    /// Runs `work` once the pause after a change is over.
    public typealias Scheduler = @MainActor (@escaping @MainActor () -> Void) -> Void

    /// The writes the review asks for, by day.
    public struct Actions {
        let save: (String, ReviewValues) -> Void
        /// The draft, closed, and where each unfinished task goes, in the list's order.
        let shutDown: (String, ReviewValues, [TaskRollover]) -> Void

        public init(
            save: @escaping (String, ReviewValues) -> Void,
            shutDown: @escaping (String, ReviewValues, [TaskRollover]) -> Void
        ) { (self.save, self.shutDown) = (save, shutDown) }
    }

    public static let ratings = 1...5
    /// What the closed day says (IDEA §8.2, step 6).
    public static let shutdownLine = "Great work today. Time to rest."

    public private(set) var day: String?
    public private(set) var draft = ReviewValues.empty
    /// Only the changed choices; every other task goes to tomorrow.
    private var choices: [String: RescheduleOption] = [:]

    @ObservationIgnored private let actions: Actions
    @ObservationIgnored private let schedule: Scheduler
    @ObservationIgnored private let calendar: Calendar
    /// A change not yet saved, and which change the latest pause belongs to.
    @ObservationIgnored private var isPending = false
    @ObservationIgnored private var generation = 0

    public init(
        actions: Actions, schedule: @escaping Scheduler = ReviewModel.afterPause(.milliseconds(800)),
        calendar: Calendar = .current
    ) { (self.actions, self.schedule, self.calendar) = (actions, schedule, calendar) }

    public var isShutdown: Bool { draft.isShutdown }

    /// Shows `values` for `day`. The store's copy never overwrites an edit
    /// still waiting to save; a new day saves the old day's edit first.
    public func load(day: String, values: ReviewValues) {
        guard day == self.day else {
            flush()
            (self.day, draft, choices) = (day, values, [:])
            return
        }
        guard !isPending else { return }
        draft = values
    }

    /// Chooses a rating; choosing the chosen one again clears it.
    public func chooseRating(_ rating: Int) { change { $0.rating = $0.rating == rating ? nil : rating } }

    /// Chooses an energy; choosing the chosen one again clears it.
    public func chooseEnergy(_ energy: Int) { change { $0.energy = $0.energy == energy ? nil : energy } }

    public func setWin(_ win: String) { change { $0.win = win } }

    public func rollover(for id: String) -> RescheduleOption { choices[id] ?? .tomorrow }

    public func chooseRollover(_ option: RescheduleOption, for id: String) { choices[id] = option }

    /// "Tomorrow", "Backlog", or the picked day as "Thu 12".
    public func rolloverLabel(for id: String) -> String {
        switch rollover(for: id) {
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        case .backlog: "Backlog"
        case .date(let date): DayString.short(DayString.format(date, calendar: calendar), calendar: calendar) ?? ""
        }
    }

    /// Closes the day: the draft, a waiting edit included, goes with every
    /// task's move in one write, counted from the review's day, not the clock.
    public func shutDown(unfinished ids: [String]) {
        guard let day else { return }
        (isPending, draft.isShutdown) = (false, true)
        let moves = ids.map { TaskRollover(taskID: $0, day: rollover(for: $0).day(from: day, calendar: calendar)) }
        choices = [:]
        actions.shutDown(day, draft, moves)
    }

    /// Opens the day again at once; the tasks already moved stay moved.
    public func reopen() {
        guard let day else { return }
        (isPending, draft.isShutdown) = (false, false)
        actions.save(day, draft)
    }

    /// The line under Shut down: what it is about to do.
    public static func shutDownHint(moving count: Int) -> String {
        switch count {
        case 0: "Closes the day"
        case 1: "Moves 1 task and closes the day"
        default: "Moves \(count) tasks and closes the day"
        }
    }

    /// Saves a waiting edit now: when the screen goes away or the day moves.
    public func flush() {
        guard isPending, let day else { return }
        isPending = false
        actions.save(day, draft)
    }

    /// The app's pause: `work` runs `pause` after the last change.
    public static func afterPause(_ pause: Duration) -> Scheduler {
        { work in
            Task { @MainActor in
                try? await Task.sleep(for: pause)
                work()
            }
        }
    }

    private func change(_ edit: (inout ReviewValues) -> Void) {
        edit(&draft)
        isPending = true
        generation += 1
        let mine = generation
        schedule { [weak self] in
            guard let self, mine == generation else { return }
            flush()
        }
    }
}
