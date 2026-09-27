import OmakaseStore

/// The form Study has open (#227), with the record it edits (nil for new).
public enum StudyForm: Equatable, Sendable {
    case semester(SemesterForm, id: String?)
    case discipline(DisciplineForm, id: String?)
    /// `rotationWeeks` is the semester's, to check the weeks a class runs in.
    case schedule(ClassScheduleForm, id: String?, rotationWeeks: Int)
    case holiday(HolidayForm, id: String?)
}

/// What the server would refuse, said before anything is sent (invariant 3
/// on the client): a blank name, an end before its start, a class ending
/// before it begins, a rotation week outside the semester's rotation.
public enum StudyCheck {
    public static func problem(_ form: StudyForm) -> String? {
        switch form {
        case .semester(let semester, _): semesterProblem(semester)
        case .discipline(let discipline, _): named(discipline.name)
        case .schedule(let schedule, _, let weeks): scheduleProblem(schedule, rotationWeeks: weeks)
        case .holiday(let holiday, _): named(holiday.name) ?? ordered(holiday.startDay, holiday.endDay)
        }
    }

    private static func semesterProblem(_ semester: SemesterForm) -> String? {
        if let problem = named(semester.name) ?? ordered(semester.startDay, semester.endDay) { return problem }
        guard (1...4).contains(semester.rotationWeeks) else {
            return "The rotation is \(semester.rotationWeeks) weeks; it can be 1 to 4."
        }
        return nil
    }

    private static func scheduleProblem(_ schedule: ClassScheduleForm, rotationWeeks: Int) -> String? {
        if schedule.endTime <= schedule.startTime {
            return "The class ends at \(clock(schedule.endTime)), before it starts at \(clock(schedule.startTime))."
        }
        guard let week = schedule.rotationWeeksOn.first(where: { !(1...rotationWeeks).contains($0) }) else {
            return nil
        }
        return "Week \(week) is outside the semester's rotation of \(rotationWeeks) weeks."
    }

    private static func named(_ name: String) -> String? {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "A name is needed." : nil
    }

    /// YYYY-MM-DD strings order as their days do.
    private static func ordered(_ start: String, _ end: String) -> String? {
        end < start ? "The end, \(end), is before the start, \(start)." : nil
    }

    private static func clock(_ time: String) -> String { String(time.prefix(5)) }
}

/// A semester's dates, for choosing the one to show.
public struct SemesterSummary: Equatable, Sendable {
    public let id: String
    public let startDay: String
    public let endDay: String

    public init(id: String, startDay: String, endDay: String) {
        (self.id, self.startDay, self.endDay) = (id, startDay, endDay)
    }
}
