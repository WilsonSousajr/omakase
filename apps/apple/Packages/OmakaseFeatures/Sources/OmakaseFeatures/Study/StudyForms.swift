import Foundation
import OmakaseStore

/// Study's new forms, a record's form for editing, and the labels its lists
/// show (#227).
public enum StudyForms {
    /// A term from today, 16 weeks long, with no rotation.
    public static func newSemester(today: String, calendar: Calendar = .current) -> SemesterForm {
        let start = DayString.date(today, calendar: calendar)
        let end = start.flatMap { calendar.date(byAdding: .day, value: 112, to: $0) }
        return SemesterForm(
            name: "", institution: "", startDay: today,
            endDay: end.map { DayString.format($0, calendar: calendar) } ?? today)
    }

    public static func newDiscipline(in semesterID: String) -> DisciplineForm {
        DisciplineForm(semesterID: semesterID, name: "", code: "", professor: "", color: ProjectsModel.palette[1])
    }

    public static func newSchedule(for disciplineID: String) -> ClassScheduleForm {
        ClassScheduleForm(
            disciplineID: disciplineID, dayOfWeek: 0, startTime: "08:00:00", endTime: "09:40:00",
            classType: "lecture", location: "")
    }

    @MainActor
    public static func newHoliday(in semester: SemesterRecord) -> HolidayForm {
        HolidayForm(semesterID: semester.id, name: "", startDay: semester.startDay, endDay: semester.startDay)
    }

    @MainActor
    public static func form(_ semester: SemesterRecord) -> SemesterForm {
        SemesterForm(
            name: semester.name, institution: semester.institution, startDay: semester.startDay,
            endDay: semester.endDay, rotationWeeks: semester.rotationWeeks, rotationAnchor: semester.rotationAnchor)
    }

    @MainActor
    public static func form(_ discipline: DisciplineRecord) -> DisciplineForm {
        DisciplineForm(
            semesterID: discipline.semesterID, name: discipline.name, code: discipline.code,
            professor: discipline.professor, color: discipline.color)
    }

    @MainActor
    public static func form(_ schedule: ClassScheduleRecord) -> ClassScheduleForm {
        ClassScheduleForm(
            disciplineID: schedule.disciplineID, dayOfWeek: schedule.dayOfWeek, startTime: schedule.startTime,
            endTime: schedule.endTime, classType: schedule.classType, location: schedule.location,
            rotationWeeksOn: schedule.rotationWeeksOn)
    }

    @MainActor
    public static func form(_ holiday: HolidayRecord) -> HolidayForm {
        HolidayForm(
            semesterID: holiday.semesterID, name: holiday.name, startDay: holiday.startDay, endDay: holiday.endDay)
    }

    public static let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    public static let classTypes = ["lecture", "lab", "tutorial", "seminar"]

    /// 0 is Monday, as the server counts.
    public static func weekdayName(_ day: Int) -> String {
        weekdays.indices.contains(day) ? weekdays[day] : "Day \(day)"
    }

    public static func weeksLabel(_ weeks: [Int]) -> String {
        let sorted = weeks.sorted()
        switch sorted.count {
        case 0: return "Every week"
        case 1: return "Week \(sorted[0])"
        default: return "Weeks " + sorted.map(String.init).joined(separator: ", ")
        }
    }
}
