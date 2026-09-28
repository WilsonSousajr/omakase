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

    /// The block a drawn slot books with its task (S11, #264), in the
    /// Store's shape; nil for every other destination.
    ///
    ///     request.destination.captureSlot   // CaptureSlot(day: "2026-09-28", start: "14:00:00", end: "15:00:00")
    public var captureSlot: CaptureSlot? {
        guard case .slot(let slot) = self else { return nil }
        return CaptureSlot(day: slot.day, start: slot.startTime, end: slot.endTime)
    }

    private static func short(_ day: String, _ calendar: Calendar) -> String {
        DayString.short(day, calendar: calendar) ?? day
    }
}

/// One save from the panel: the trimmed title, its kind and parent, where
/// it lands, and what ⌘E added (#286). The app turns it into
/// `TaskWrites.captureTask`.
public struct CaptureRequest: Equatable, Sendable {
    public let title: String
    public let filing: TaskFiling
    public let destination: CaptureDestination
    public let details: TaskCaptureDetails

    public init(
        title: String, filing: TaskFiling, destination: CaptureDestination,
        details: TaskCaptureDetails = TaskCaptureDetails()
    ) {
        (self.title, self.filing, self.destination, self.details) = (title, filing, destination, details)
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
    /// What a save asks for: the capture itself, then the kind to remember;
    /// and ⌘E, whether the panel is expanded, to remember for next time.
    public struct Actions {
        let capture: (CaptureRequest) -> Void
        let remember: (TaskArea) -> Void
        let rememberExpanded: (Bool) -> Void

        public init(
            capture: @escaping (CaptureRequest) -> Void, remember: @escaping (TaskArea) -> Void,
            rememberExpanded: @escaping (Bool) -> Void = { _ in }
        ) {
            (self.capture, self.remember, self.rememberExpanded) = (capture, remember, rememberExpanded)
        }
    }

    public var draft = ""
    /// ⌘E's fields are showing (glass-pass §4); toggled with `toggleExpanded()`.
    public internal(set) var isExpanded: Bool
    /// What ⌘E opens: the day, priority, estimate, notes and subtasks.
    public var details = CaptureDetails()
    /// A subtask line has the focus: ⏎ adds a line there, so ⌘⏎ saves where ⏎ would.
    public var isEditingSubtasks = false
    /// Set with `choose(_:)`, which keeps the parent consistent with it.
    public private(set) var area: TaskArea
    /// Set with `choose(parent:)`, which derives the area from it.
    public private(set) var parent: TaskParent?

    /// Observed, not fixed: `reseed` replaces both while the panel is open,
    /// and the hint and the parent chip redraw from them.
    private var context: CaptureContext
    private var directory: PlaceDirectory
    @ObservationIgnored let calendar: Calendar
    /// The client's day (invariant 2), read when it is needed.
    @ObservationIgnored let today: () -> String
    @ObservationIgnored let actions: Actions

    /// `isExpanded` is how the last panel was left (`CaptureExpansion`).
    public init(
        context: CaptureContext, directory: PlaceDirectory, lastArea: TaskArea, isExpanded: Bool = false,
        calendar: Calendar = .current, today: @escaping () -> String = { FocusDay().today }, actions: Actions
    ) {
        (self.context, self.directory, self.calendar, self.actions) = (context, directory, calendar, actions)
        (self.isExpanded, self.today) = (isExpanded, today)
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

// MARK: - Opened again while open

extension CaptureModel {
    /// The panel was asked for again while open, say by a slot drawn on Plan
    /// (spec §9, #264): the new context's destination wins, and its filing
    /// when it names one; the draft being typed, and a kind chosen when the
    /// context names none, stay. `directory` is read again, as a new panel
    /// would read it.
    ///
    /// A slot already drawn stays when the new context has none, as with ⌘N
    /// over the open panel, and a new slot replaces a picked day. A kept
    /// parent the re-read places no longer list is dropped (S11's review, #286).
    ///
    ///     model.reseed(context: CaptureContext(slot: slot), directory: services.capturePlaces())
    public func reseed(context: CaptureContext, directory: PlaceDirectory) {
        if context.slot != nil { details.date = nil }
        let slot = context.slot ?? self.context.slot
        self.context = CaptureContext(filing: context.filing, day: context.day, slot: slot)
        self.directory = directory
        guard let filing = context.filing else { return dropParentIfUnlisted() }
        (area, parent) = (filing.area, filing.parent)
    }

    private func dropParentIfUnlisted() {
        guard let parent, !parentChoices.contains(where: { $0.parent == parent }) else { return }
        self.parent = nil
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
    /// Where ⏎ saves (spec §4): a picked day (glass-pass §4), else the drawn
    /// slot, else the day, else Today.
    public var enterDestination: CaptureDestination {
        if let date = details.date { return destination(picked: date) }
        if let slot = context.slot { return .slot(slot) }
        if let day = context.day { return .day(day) }
        return .today
    }

    /// A picked day keeps the drawn slot when it is the slot's own day, and
    /// is Today when it is the client's.
    private func destination(picked date: String) -> CaptureDestination {
        if let slot = context.slot, slot.day == date { return .slot(slot) }
        return date == today() ? .today : .day(date)
    }

    /// The footer: the keys, and what ⏎ does in this context. In a subtask
    /// line ⏎ adds a line, so ⌘⏎ takes ⏎'s save.
    public var hint: String {
        let destination = enterDestination.title(calendar: calendar)
        guard isEditingSubtasks else { return "⌘E more/less · ⏎ \(destination) · ⌘⏎ Inbox · ⎋" }
        return "⌘E more/less · ⏎ new subtask · ⌘⏎ \(destination) · ⎋"
    }

    /// Saves the draft to `destination` as the current filing, with what ⌘E
    /// added, remembers the kind and clears the draft and its details; an
    /// empty or whitespace-only title saves nothing and returns false.
    @discardableResult
    public func save(to destination: CaptureDestination) -> Bool {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        actions.capture(
            CaptureRequest(title: title, filing: filing, destination: destination, details: details.taskDetails))
        actions.remember(area)
        clearDraft()
        return true
    }

    /// ⏎: saves to `enterDestination`.
    @discardableResult
    public func saveEnter() -> Bool { save(to: enterDestination) }

    /// ⌘⏎: saves to the Inbox, whatever the context.
    @discardableResult
    public func saveInbox() -> Bool { save(to: .inbox) }

    /// Drops the draft: the panel is closed, never hidden, so nothing stale returns.
    public func dismiss() { clearDraft() }

    private func clearDraft() { (draft, details, isEditingSubtasks) = ("", CaptureDetails(), false) }
}
