import Observation

/// The day's review draft: rating, energy and win, each change saved after a
/// short pause so typing is one write and quitting halfway loses nothing
/// (M3.4 spec, Decisions). The write and the pause are injected, so the app
/// wires the outbox and tests hold the pause.
///
/// Rollover choices and Shut down/Reopen (#179) join here: a choice per
/// unfinished task beside `draft`, and a `shutDown` action beside `save`.
///
///     let model = ReviewModel(actions: .init(save: { day, values in … }))
///     model.load(day: "2026-03-07", values: ReviewValues(record: stored))
///     model.chooseRating(4)
@Observable
@MainActor
public final class ReviewModel {
    /// Runs `work` once the pause after a change is over.
    public typealias Scheduler = @MainActor (@escaping @MainActor () -> Void) -> Void

    /// The writes the review asks for, by day.
    public struct Actions {
        let save: (String, ReviewValues) -> Void

        public init(save: @escaping (String, ReviewValues) -> Void) { self.save = save }
    }

    public static let ratings = 1...5

    public private(set) var day: String?
    public private(set) var draft = ReviewValues.empty

    @ObservationIgnored private let actions: Actions
    @ObservationIgnored private let schedule: Scheduler
    /// A change not yet saved, and which change the latest pause belongs to.
    @ObservationIgnored private var isPending = false
    @ObservationIgnored private var generation = 0

    public init(actions: Actions, schedule: @escaping Scheduler = ReviewModel.afterPause(.milliseconds(800))) {
        (self.actions, self.schedule) = (actions, schedule)
    }

    /// Shows `values` for `day`. The store's copy never overwrites an edit
    /// still waiting to save; a new day saves the old day's edit first.
    public func load(day: String, values: ReviewValues) {
        guard day == self.day else {
            flush()
            (self.day, draft) = (day, values)
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
