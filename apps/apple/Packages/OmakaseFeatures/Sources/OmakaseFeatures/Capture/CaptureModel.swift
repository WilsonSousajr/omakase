import Foundation
import Observation
import OmakaseStore

/// Where a capture lands (spec §4): Today, the day Plan shows, a slot drawn
/// on Plan (S11, #264), or the Inbox. The M3.5 panel had only Today and the
/// Inbox, Today by default because an undated task would vanish until M5.
public enum CaptureDestination: Equatable, Sendable {
    case today
    case day(String)
    case slot(PlanPlacement)
    case inbox

    /// What the hint calls it: "Today", "Mon 28", "Mon 28, 14:00" or "Inbox".
    /// A day that doesn't parse is shown as it is, as Plan's headers do.
    public func title(calendar: Calendar = .current) -> String {
        switch self {
        case .today: "Today"
        case .inbox: "Inbox"
        case .day(let day): Self.short(day, calendar)
        case .slot(let slot): "\(Self.short(slot.day, calendar)), \(CalendarItem.clock(slot.start))"
        }
    }

    /// The day the task is scheduled on: `today` (the client's day,
    /// invariant 2), Plan's day, a slot's day, so adding its block queues no
    /// reschedule (spec §9), or nil for the Inbox.
    ///
    ///     CaptureDestination.today.scheduledDay(today: FocusDay().today)
    public func scheduledDay(today: String) -> String? {
        switch self {
        case .today: today
        case .day(let day): day
        case .slot(let slot): slot.day
        case .inbox: nil
        }
    }

    private static func short(_ day: String, _ calendar: Calendar) -> String {
        DayString.short(day, calendar: calendar) ?? day
    }
}

/// One save from the panel: the trimmed title, its kind and parent, and
/// where it lands. The app turns it into `TaskWrites.capture`.
public struct CaptureRequest: Equatable, Sendable {
    public let title: String
    public let filing: TaskFiling
    public let destination: CaptureDestination

    public init(title: String, filing: TaskFiling, destination: CaptureDestination) {
        (self.title, self.filing, self.destination) = (title, filing, destination)
    }
}

extension TaskArea {
    /// The remembered kind (spec §4, UserDefaults' `omakase.capture.area`):
    /// a stored raw value, with a missing or unknown one read as Work.
    ///
    ///     TaskArea(storedRaw: defaults.string(forKey: "omakase.capture.area"))
    public init(storedRaw: String?) {
        self = storedRaw.map(TaskArea.init(wire:)) ?? .work
    }
}

/// The capture panel's draft, kind and parent (spec §4). It opens from a
/// `CaptureContext`, so ⏎ saves where the user was; the write and the
/// remembered kind are injected, so the app sends them through the store
/// and UserDefaults and tests record them.
///
///     let model = CaptureModel(context: .init(day: "2026-09-28"), directory: directory, lastArea: .work,
///                              actions: .init(capture: { request in … }, remember: { area in … }))
///     model.draft = "Email the advisor"
///     model.saveEnter()   // true: Mon 28, as Work, and the draft is empty again
@Observable
@MainActor
public final class CaptureModel {
    /// What a save asks for: the capture itself, then the kind to remember.
    public struct Actions {
        let capture: (CaptureRequest) -> Void
        let remember: (TaskArea) -> Void

        public init(capture: @escaping (CaptureRequest) -> Void, remember: @escaping (TaskArea) -> Void) {
            (self.capture, self.remember) = (capture, remember)
        }
    }

    public var draft = ""
    /// Set with `choose(_:)`, which keeps the parent consistent with it.
    public private(set) var area: TaskArea
    /// Set with `choose(parent:)`, which derives the area from it.
    public private(set) var parent: TaskParent?

    @ObservationIgnored private let context: CaptureContext
    @ObservationIgnored private let directory: PlaceDirectory
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let actions: Actions

    public init(
        context: CaptureContext, directory: PlaceDirectory, lastArea: TaskArea, calendar: Calendar = .current,
        actions: Actions
    ) {
        (self.context, self.directory, self.calendar, self.actions) = (context, directory, calendar, actions)
        area = context.filing?.area ?? lastArea
        parent = context.filing?.parent
    }

    /// The kind and parent a save sends, derived in the store's one place.
    public var filing: TaskFiling { TaskFiling(area: area, parent: parent) }

    /// Picks a kind (⌘1–3 or a chip), dropping a parent that no longer fits:
    /// a discipline under Work, a project under Study, any parent under Life.
    public func choose(_ area: TaskArea) {
        self.area = area
        guard let parent, TaskFiling(area: area, parent: parent).area != area else { return }
        self.parent = nil
    }

    /// Picks a parent, or none, and the kind it implies (spec §1).
    public func choose(parent: TaskParent?) {
        let filing = TaskFiling(area: area, parent: parent)
        (area, self.parent) = (filing.area, filing.parent)
    }
}

// MARK: - The parent chip

extension CaptureModel {
    /// The current kind's places: Work's projects, Study's disciplines, none for Life.
    public var parentChoices: [PlaceEntry] { directory.places(for: area) }

    /// The parent menu's sections, a workspace each.
    public var parentGroups: [PlaceGroup] { PlaceGroup.groups(of: parentChoices) }

    /// Hidden for Life, and whenever the kind has no places to offer (an
    /// empty library cache): the kind alone still saves.
    public var showsParentChip: Bool { !parentChoices.isEmpty }

    /// The chip's label: the parent's name, or which kind of parent is missing.
    public var parentTitle: String {
        guard parent != nil else { return area == .study ? "No discipline" : "No project" }
        return directory.mark(for: filing).title
    }
}

// MARK: - Saving

extension CaptureModel {
    /// Where ⏎ saves (spec §4): the drawn slot, else the day, else Today.
    public var enterDestination: CaptureDestination {
        if let slot = context.slot { return .slot(slot) }
        if let day = context.day { return .day(day) }
        return .today
    }

    /// The footer: the keys, and what ⏎ does in this context.
    public var hint: String {
        "⌘1–3 kind · ⏎ \(enterDestination.title(calendar: calendar)) · ⌘⏎ Inbox · ⎋ dismiss"
    }

    /// Saves the draft to `destination` as the current filing, remembers the
    /// kind and clears the draft; an empty or whitespace-only title saves
    /// nothing and returns false.
    @discardableResult
    public func save(to destination: CaptureDestination) -> Bool {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        actions.capture(CaptureRequest(title: title, filing: filing, destination: destination))
        actions.remember(area)
        draft = ""
        return true
    }

    /// ⏎: saves to `enterDestination`.
    @discardableResult
    public func saveEnter() -> Bool { save(to: enterDestination) }

    /// ⌘⏎: saves to the Inbox, whatever the context.
    @discardableResult
    public func saveInbox() -> Bool { save(to: .inbox) }

    /// Drops the draft: the panel is closed, never hidden, so nothing stale returns.
    public func dismiss() { draft = "" }
}
