import OmakaseStore

/// An open task's fields the sidebar counts by (spec §6): plain values, so
/// the tally is testable without SwiftData.
public struct SidebarOpenTask: Equatable, Sendable {
    /// The wire value, as `TaskRecord.area` holds it (`personal` is Life).
    public let area: String
    public let projectID: String?
    public let disciplineID: String?
    public let scheduledDay: String?
    public let isVirtual: Bool

    public init(area: String, projectID: String?, disciplineID: String?, scheduledDay: String?, isVirtual: Bool) {
        (self.area, self.projectID, self.disciplineID) = (area, projectID, disciplineID)
        (self.scheduledDay, self.isVirtual) = (scheduledDay, isVirtual)
    }

    @MainActor
    public init(_ record: TaskRecord) {
        self.init(
            area: record.area, projectID: record.projectID, disciplineID: record.disciplineID,
            scheduledDay: record.scheduledDay, isVirtual: record.isVirtual)
    }

    /// The places whose list shows this task: exactly what each
    /// `TaskPlace.openTasksPredicate` matches, so a count never disagrees
    /// with the list it opens. A virtual occurrence is the calendar's (spec §5).
    fileprivate var places: [TaskPlace] {
        guard !isVirtual else { return [] }
        let life: TaskPlace? = area == TaskArea.life.rawValue ? .life : nil
        return [projectID.map(TaskPlace.project), disciplineID.map(TaskPlace.discipline), life].compactMap { $0 }
    }
}

/// How many open tasks each place and the Inbox hold (spec §6): one query
/// of the open tasks, tallied here, rather than one query per place.
///
///     let counts = SidebarCounts.tally(openTasks.map(SidebarOpenTask.init))
///     counts.count(for: .discipline("d1"))   // 4
public struct SidebarCounts: Equatable, Sendable {
    public let places: [TaskPlace: Int]
    /// Open tasks with no day, as the Inbox lists them (#225).
    public let inbox: Int

    public init(places: [TaskPlace: Int], inbox: Int) { (self.places, self.inbox) = (places, inbox) }

    /// Counts each open task toward the places whose list shows it, and
    /// toward the Inbox when it has no day.
    public static func tally(_ tasks: [SidebarOpenTask]) -> SidebarCounts {
        var places: [TaskPlace: Int] = [:]
        for place in tasks.flatMap(\.places) { places[place, default: 0] += 1 }
        return SidebarCounts(places: places, inbox: tasks.count { $0.scheduledDay == nil })
    }

    /// The place's open tasks; zero for a place with none.
    public func count(for place: TaskPlace) -> Int { places[place] ?? 0 }
}
