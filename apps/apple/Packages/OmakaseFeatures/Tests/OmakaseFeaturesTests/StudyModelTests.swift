import Foundation
import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// Study (#227): semesters, disciplines, class schedules and holidays, each a
/// form checked before it is sent, then written online.
@MainActor
struct StudyModelTests {
    final class Recorder {
        var calls: [String] = []
        var failure: Error?
    }

    struct Offline: Error, CustomStringConvertible { var description: String { "Needs a connection." } }

    private let recorder = Recorder()

    private func model() -> StudyModel {
        let recorder = recorder
        func record(_ call: String) throws {
            if let failure = recorder.failure { throw failure }
            recorder.calls.append(call)
        }
        return StudyModel(
            actions: .init(
                saveSemester: { form, id in try record("semester \(form.name) \(id ?? "new")") },
                saveDiscipline: { form, id in try record("discipline \(form.name) \(id ?? "new")") },
                saveSchedule: { form, id in try record("schedule \(form.dayOfWeek) \(id ?? "new")") },
                saveHoliday: { form, id in try record("holiday \(form.name) \(id ?? "new")") },
                delete: { deletion in try record("delete \(deletion.id)") }))
    }

    private let fall = SemesterForm(name: "Fall", institution: "", startDay: "2026-08-01", endDay: "2026-12-15")

    @Test func aValidSemesterIsSavedAndTheFormCloses() async {
        let study = model()
        study.editing = .semester(fall, id: nil)
        await study.saveEditing()
        #expect(recorder.calls == ["semester Fall new"] && study.editing == nil)
    }

    @Test func aProblemIsSaidBeforeAnythingIsSent() async {
        let study = model()
        var backwards = fall
        backwards.endDay = "2026-07-01"
        study.editing = .semester(backwards, id: nil)
        await study.saveEditing()
        #expect(recorder.calls.isEmpty && study.editing != nil)
        #expect(study.message == "The end, 2026-07-01, is before the start, 2026-08-01.")
    }

    @Test func theChecksCoverSemesters() {
        #expect(
            StudyCheck.problem(
                .semester(
                    SemesterForm(name: " ", institution: "", startDay: "2026-01-01", endDay: "2026-02-01"), id: nil))
                == "A name is needed.")
        let rotation = SemesterForm(
            name: "Fall", institution: "", startDay: "2026-01-01", endDay: "2026-02-01", rotationWeeks: 5)
        #expect(StudyCheck.problem(.semester(rotation, id: nil)) == "The rotation is 5 weeks; it can be 1 to 4.")
    }

    @Test func theChecksCoverClassesAndHolidays() {
        let late = ClassScheduleForm(
            disciplineID: "d", dayOfWeek: 0, startTime: "11:00:00", endTime: "10:00:00", classType: "lecture",
            location: "")
        #expect(
            StudyCheck.problem(.schedule(late, id: nil, rotationWeeks: 1))
                == "The class ends at 10:00, before it starts at 11:00.")
        let offRotation = ClassScheduleForm(
            disciplineID: "d", dayOfWeek: 0, startTime: "10:00:00", endTime: "11:00:00", classType: "lecture",
            location: "", rotationWeeksOn: [3])
        #expect(
            StudyCheck.problem(.schedule(offRotation, id: nil, rotationWeeks: 2))
                == "Week 3 is outside the semester's rotation of 2 weeks.")
        let holiday = HolidayForm(semesterID: "s", name: "Easter", startDay: "2026-04-10", endDay: "2026-04-03")
        #expect(
            StudyCheck.problem(.holiday(holiday, id: nil)) == "The end, 2026-04-03, is before the start, 2026-04-10.")
    }

    @Test func aRefusalKeepsTheFormOpenAndSaysWhy() async {
        recorder.failure = Offline()
        let study = model()
        study.editing = .discipline(
            DisciplineForm(semesterID: "s", name: "Calculus", code: "", professor: "", color: "#3b82f6"), id: "d1")
        await study.saveEditing()
        #expect(study.editing != nil && study.message == "Needs a connection.")
    }

    @Test func deletesAskFirstAndSayWhatGoes() async {
        let study = model()
        study.askToDelete(.semester(id: "s1"))
        #expect(study.deleting?.warning == "Its disciplines, their classes and its holidays go too.")
        await study.confirmDelete()
        #expect(recorder.calls == ["delete s1"])
        #expect(
            StudyModel.Deletion.discipline(id: "d1").warning == "Its classes go too. Its tasks and study blocks stay.")
    }

    @Test func cancellingClosesTheFormAndItsMessage() async {
        let study = model()
        study.editing = .holiday(
            HolidayForm(semesterID: "s", name: "", startDay: "2026-04-03", endDay: "2026-04-03"), id: nil)
        await study.saveEditing()
        #expect(study.message == "A name is needed.")
        study.cancelEditing()
        #expect(study.editing == nil && study.message == nil)
        #expect(StudyModel.Deletion.schedule(id: "c").warning == "Its classes leave the calendar.")
        #expect(StudyModel.Deletion.holiday(id: "h").warning == "Its days have classes again.")
    }

    @Test func theDefaultSemesterIsTheOneTodayIsIn() {
        let semesters = [
            SemesterSummary(id: "old", startDay: "2026-02-01", endDay: "2026-06-30"),
            SemesterSummary(id: "now", startDay: "2026-08-01", endDay: "2026-12-15"),
            SemesterSummary(id: "next", startDay: "2027-02-01", endDay: "2027-06-30"),
        ]
        #expect(StudyModel.defaultSemester(semesters, today: "2026-09-27") == "now")
        // Between terms, the next to start; after them all, the latest.
        #expect(StudyModel.defaultSemester(semesters, today: "2026-07-15") == "now")
        #expect(StudyModel.defaultSemester(semesters, today: "2027-01-10") == "next")
        #expect(StudyModel.defaultSemester(semesters, today: "2028-01-01") == "next")
        #expect(StudyModel.defaultSemester([], today: "2026-07-15") == nil)
    }
}
