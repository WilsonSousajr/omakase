import Foundation
import Testing

@testable import OmakaseAPI

/// One `ClassOccurrenceSerializer` item, copied from backend/study/serializers.py's
/// fields; `study_class_occurrences.json` is the backend-written one (#207).
enum ClassOccurrenceSample {
    static let id = "2b1f0c7e-9d4a-4c31-8a55-0e6f3d2c1b90-2026-09-22"
    static let json = """
        {"id":"\(id)","class_schedule_id":"2b1f0c7e-9d4a-4c31-8a55-0e6f3d2c1b90",
         "discipline_name":"Calculus","discipline_color":"#3B82F6","class_type":"lecture",
         "location":"Room 101","date":"2026-09-22","start_time":"08:00:00","end_time":"09:40:00","week":1,"is_cancelled":false}
        """
}

struct ClassOccurrenceDTOTests {
    @Test func decodesAnOccurrence() throws {
        let occurrence = try OmakaseJSON.decoder.decode(
            ClassOccurrenceDTO.self, from: Data(ClassOccurrenceSample.json.utf8))
        #expect(occurrence.id == ClassOccurrenceSample.id && occurrence.date.string == "2026-09-22")
        #expect(occurrence.classScheduleId.uuidString == "2B1F0C7E-9D4A-4C31-8A55-0E6F3D2C1B90")
        #expect(occurrence.disciplineName == "Calculus" && occurrence.disciplineColor == "#3B82F6")
        #expect(occurrence.classType == "lecture" && occurrence.location == "Room 101")
        #expect(occurrence.startTime == "08:00:00" && occurrence.endTime == "09:40:00")
    }

    @Test func decodesACancelledOccurrenceFromTheBackendFixture() throws {
        let occurrences = try OmakaseJSON.decoder.decode(
            [ClassOccurrenceDTO].self, from: try Fixture.data("study_class_occurrences"))
        let occurrence = try #require(occurrences.first)
        #expect(occurrence.isCancelled && occurrence.week == 1)
        #expect(occurrence.id == "b4933eb0-9ad5-4f3a-bcea-9940d164cea9-2026-03-02")
    }

    @Test func aSampleOccurrenceIsNotCancelled() throws {
        let occurrence = try OmakaseJSON.decoder.decode(
            ClassOccurrenceDTO.self, from: Data(ClassOccurrenceSample.json.utf8))
        #expect(!occurrence.isCancelled && occurrence.week == 1)
    }
}
