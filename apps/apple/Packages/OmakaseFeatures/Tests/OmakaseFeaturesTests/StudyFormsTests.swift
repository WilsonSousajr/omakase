import Foundation
import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// Study's new forms and labels (#227).
struct StudyFormsTests {
    @Test func aNewSemesterStartsTodayAndRunsSixteenWeeks() {
        let form = StudyForms.newSemester(today: "2026-09-27")
        #expect(form.startDay == "2026-09-27" && form.endDay == "2027-01-17" && form.rotationWeeks == 1)
        #expect(form.name.isEmpty && form.rotationAnchor == nil)
    }

    @Test func aNewClassIsAMondayMorningLectureEveryWeek() {
        let form = StudyForms.newSchedule(for: "d1")
        #expect(form.disciplineID == "d1" && form.dayOfWeek == 0 && form.classType == "lecture")
        #expect(form.startTime == "08:00:00" && form.endTime == "09:40:00" && form.rotationWeeksOn.isEmpty)
    }

    @Test func weekdaysAreNamedMondayFirst() {
        #expect(StudyForms.weekdayName(0) == "Monday" && StudyForms.weekdayName(6) == "Sunday")
        #expect(StudyForms.weekdayName(9) == "Day 9")
    }

    @Test func theWeeksAClassRunsInAreSaid() {
        #expect(StudyForms.weeksLabel([]) == "Every week")
        #expect(StudyForms.weeksLabel([1]) == "Week 1")
        #expect(StudyForms.weeksLabel([3, 1]) == "Weeks 1, 3")
    }

    @Test func aNewDisciplineTakesTheFirstColour() {
        let form = StudyForms.newDiscipline(in: "s1")
        #expect(form.semesterID == "s1" && form.color == ProjectsModel.palette[1] && form.name.isEmpty)
    }
}
