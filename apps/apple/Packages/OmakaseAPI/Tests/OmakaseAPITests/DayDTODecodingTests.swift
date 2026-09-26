import Foundation
import Testing

@testable import OmakaseAPI

struct DayDTODecodingTests {
    @Test func todaysTasksCarryTheirSubtasks() throws {
        let page = try OmakaseJSON.decoder.decode(Page<TaskDTO>.self, from: Fixture.data("tasks_today"))
        let subtask = try #require(page.results.first?.subtasks?.first)
        #expect(subtask.title == "Outline" && !subtask.isCompleted)
    }

    @Test func aTaskWithoutEmbeddedSubtasksDecodesAsNil() throws {
        // The plain tasks/ list sends no `subtasks`: nil, so sync leaves local subtasks alone.
        let page = try JSONSerialization.jsonObject(with: Fixture.data("tasks_today")) as? [String: Any]
        var task = try #require((page?["results"] as? [[String: Any]])?.first)
        task["subtasks"] = nil
        let data = try JSONSerialization.data(withJSONObject: task)
        #expect(try OmakaseJSON.decoder.decode(TaskDTO.self, from: data).subtasks == nil)
    }

    @Test func decodesCarriedOverAsAPlainList() throws {
        let tasks = try OmakaseJSON.decoder.decode([TaskDTO].self, from: Fixture.data("tasks_carried_over"))
        #expect(tasks.first?.scheduledDate?.string == "2026-03-06")
    }

    @Test func decodesTheDaysTimeBlocks() throws {
        let page = try OmakaseJSON.decoder.decode(Page<TimeBlockDTO>.self, from: Fixture.data("timeblocks_day"))
        let block = try #require(page.results.first)
        #expect(block.date.string == "2026-03-07" && block.notes == "Draft" && block.sessionRating == 4)
        #expect(block.task != nil && block.studyBlock == nil)
    }

    @Test func decodesTheDaysStudyBlocks() throws {
        let page = try OmakaseJSON.decoder.decode(Page<StudyBlockDTO>.self, from: Fixture.data("studyblocks_day"))
        #expect(page.results.first?.estimatedMinutes == 45)
    }

    @Test func decodesASession() throws {
        let session = try OmakaseJSON.decoder.decode(PomodoroSessionDTO.self, from: Fixture.data("pomodoro_session"))
        #expect(session.timeBlock != nil && session.completed && session.durationMinutes == 25)
    }

    @Test func decodesAReviewWithEnergy() throws {
        let review = try OmakaseJSON.decoder.decode(DailyReviewDTO.self, from: Fixture.data("review_by_date"))
        #expect(review.energy == 2 && review.productivityRating == 4 && !review.isShutdown)
    }

    @Test func decodesDecimalGoalHoursAsStrings() throws {
        // Review Focus 1: DRF sends DecimalField as "8.0", not 8.0.
        let profile = try OmakaseJSON.decoder.decode(ProfileDTO.self, from: Fixture.data("profile"))
        #expect(profile.pomodoroWorkMinutes == 25 && profile.pomodorosBeforeLongBreak == 4)
        #expect(profile.workGoalHours == 8)
    }
}
