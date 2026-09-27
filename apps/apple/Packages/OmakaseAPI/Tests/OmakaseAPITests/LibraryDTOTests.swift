import Foundation
import Testing

@testable import OmakaseAPI

/// The library's lists, decoded from the backend-written fixtures (#223, #224).
struct LibraryDTOTests {
    private func first<T: Codable & Sendable & Equatable>(_ type: T.Type, _ name: String) throws -> T {
        let page = try OmakaseJSON.decoder.decode(Page<T>.self, from: try Fixture.data(name))
        return try #require(page.results.first)
    }

    @Test func decodesAWorkspace() throws {
        let workspace = try first(WorkspaceDTO.self, "workspaces_list")
        #expect(workspace.name == "Client work" && workspace.color == "#a3a3a3" && workspace.projectCount == 1)
    }

    @Test func decodesAProject() throws {
        let project = try first(ProjectDTO.self, "projects_list")
        #expect(project.name == "Project 1" && project.status == "active" && project.taskCount == 1)
        #expect(project.dueDate?.string == "2026-06-30" && project.description.isEmpty)
    }

    @Test func decodesASemesterWithItsRotation() throws {
        let semester = try first(SemesterDTO.self, "study_semesters_list")
        #expect(semester.name == "Semester 3" && semester.status == "active")
        #expect(semester.startDate.string == "2026-03-01" && semester.endDate.string == "2026-07-15")
        #expect(semester.rotationWeeks == 2 && semester.rotationAnchor?.string == "2026-03-02")
    }

    @Test func decodesADiscipline() throws {
        let discipline = try first(DisciplineDTO.self, "study_disciplines_list")
        #expect(discipline.name == "Discipline 3" && discipline.code == "DISC003")
        #expect(discipline.professor == "Dr. Lovelace" && discipline.credits == 4)
    }

    @Test func decodesAClassScheduleWithItsRotationWeeks() throws {
        let schedule = try first(ClassScheduleDTO.self, "study_classschedules_list")
        #expect(schedule.dayOfWeek == 0 && schedule.startTime == "10:00:00" && schedule.endTime == "11:40:00")
        #expect(schedule.classType == "lecture" && schedule.isActive && schedule.rotationWeeksOn == [1])
    }

    @Test func decodesAHoliday() throws {
        let holiday = try first(HolidayDTO.self, "study_holidays_list")
        #expect(holiday.name == "Easter" && holiday.startDate.string == "2026-04-03")
        #expect(holiday.endDate.string == "2026-04-10")
    }
}

/// Settings shows the profile's timezone and Plan's week follows its week
/// start (M5 spec, Decisions).
struct ProfileWeekTests {
    @Test func decodesTheTimezoneAndTheWeekStart() throws {
        let profile = try OmakaseJSON.decoder.decode(ProfileDTO.self, from: Fixture.data("profile_patch"))
        #expect(profile.timezone == "UTC" && profile.weekStartsOn == "sunday")
        #expect(profile.blockReminderMinutes == 10 && profile.shutdownReminderTime == "18:30:00")
    }
}
