import OmakaseStore

/// The sync glyph (in the sidebar's footer since #260, the toolbar's before),
/// from whether the server is reachable and what the outbox holds (M3.5
/// spec, Decisions: the indicator). A parked write wins
/// over everything, offline included, because only the user can clear it.
///
///     let indicator = SyncIndicator(isOnline: true, status: maintenance.status())
///     Label(indicator.label, systemImage: indicator.symbol)
public enum SyncIndicator: Equatable, Sendable {
    case synced
    case offline(queued: Int)
    case queued(Int)
    case failed(Int)

    public init(isOnline: Bool, status: OutboxStatus) {
        if !status.parked.isEmpty {
            self = .failed(status.parked.count)
        } else if !isOnline {
            self = .offline(queued: status.pendingCount)
        } else {
            self = status.pendingCount == 0 ? .synced : .queued(status.pendingCount)
        }
    }

    public var symbol: String {
        switch self {
        case .synced: "checkmark.icloud"
        case .offline: "icloud.slash"
        case .queued: "arrow.triangle.2.circlepath.icloud"
        case .failed: "exclamationmark.icloud"
        }
    }

    public var label: String {
        switch self {
        case .synced: "Synced"
        case .offline(let queued): queued == 0 ? "Offline" : "Offline · \(queued) queued"
        case .queued(let count): "\(count) queued"
        case .failed(let count): "\(count) failed"
        }
    }

    /// A tap opens the failed-writes sheet rather than the status popover.
    public var opensFailedWrites: Bool {
        if case .failed = self { return true }
        return false
    }
}

extension ParkedWrite {
    private static let actionTitles = [
        "task.create": "Create task", "task.patch": "Update task", "subtask.patch": "Update subtask",
        "block.patch": "Update block", "block.create": "Create block", "block.delete": "Delete block",
        "task.delete": "Delete task",
        "session.create": "Record focus session", "review.put": "Save review",
        "task.materialize": "Save repeating task", "task.recurrence": "Set repeat",
        "task.recurrence.stop": "Stop repeat",
        "class.cancel": "Cancel class", "class.restore": "Restore class",
    ]

    /// What the write was doing, in the user's words; an unknown kind shows as itself.
    public var actionTitle: String { Self.actionTitles[kind] ?? kind }
}
