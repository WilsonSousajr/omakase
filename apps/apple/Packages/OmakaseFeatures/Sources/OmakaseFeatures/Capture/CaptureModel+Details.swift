import Foundation

// MARK: - ⌘E and its fields (glass-pass §4, #286)

extension CaptureModel {
    /// The estimate menu's choices, in minutes.
    public static let estimateChoices = [15, 30, 45, 60, 90, 120, 180, 240]

    /// ⌘E or More/Less: shows or hides the fields, and remembers which for
    /// the next panel. Collapsed, no subtask line has the focus any more.
    public func toggleExpanded() {
        isExpanded.toggle()
        if !isExpanded { isEditingSubtasks = false }
        actions.rememberExpanded(isExpanded)
    }

    /// The date field: the picked day, else where ⏎ saves now. Setting it
    /// picks that day, which replaces ⏎'s default.
    public var pickedDate: Date {
        get {
            let day = details.date ?? enterDestination.scheduledDay(today: today()) ?? today()
            return DayString.date(day, calendar: calendar) ?? .now
        }
        set { details.date = DayString.format(newValue, calendar: calendar) }
    }

    /// The chosen priority chip: Medium, the server's default, until one is chosen.
    public var shownPriority: String { details.priority ?? "medium" }

    public func choose(priority: String) { details.priority = priority }

    /// Picks an estimate, or none.
    public func choose(estimate minutes: Int?) { details.estimateMinutes = minutes }

    /// The estimate menu's label: "Estimate", or the minutes as "1h 30m".
    public var estimateTitle: String { details.estimateMinutes.map(MinutesText.format) ?? "Estimate" }
}

// MARK: - Subtasks, one per line

extension CaptureModel {
    /// Line `index`, or empty for one that is gone (the lines were cleared
    /// by a save while a field still held its index).
    public func subtask(at index: Int) -> String {
        details.subtasks.indices.contains(index) ? details.subtasks[index] : ""
    }

    public func setSubtask(_ title: String, at index: Int) {
        guard details.subtasks.indices.contains(index) else { return }
        details.subtasks[index] = title
    }

    /// ⏎ in line `index`: a new line after it, whose index is returned for
    /// the focus to move to; a blank or missing line adds nothing.
    public func addSubtaskLine(after index: Int) -> Int? {
        let title = subtask(at: index).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        details.subtasks.insert("", at: index + 1)
        return index + 1
    }

    /// ⌘⏎: in a subtask line it saves where ⏎ would, since ⏎ adds a line
    /// there; anywhere else it saves to the Inbox.
    @discardableResult
    public func saveCommandReturn() -> Bool { isEditingSubtasks ? saveEnter() : saveInbox() }
}
