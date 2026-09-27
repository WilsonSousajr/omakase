import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// Study (#227), written online: semesters, disciplines, class schedules
/// and holidays, each a whole form; a delete takes what the server cascades.
@MainActor
struct StudyWritesTests {
    let container: ModelContainer
    let api = FakeAPIClient()

    init() throws { container = try StoreSchema.container(inMemory: true) }

    private var context: ModelContext { container.mainContext }
    private var writes: StudyWrites { StudyWrites(api: api, context: context) }
    private let semesterID = LibrarySample.semesterID
    private let disciplineID = LibrarySample.disciplineID

    private func semesterJSON(name: String = "Fall") -> String {
        ##"{"id":"\##(semesterID)","name":"\##(name)","institution":"UFRJ","start_date":"2026-08-01","##
            + ##""end_date":"2026-12-15","status":"active","rotation_weeks":2,"rotation_anchor":null}"##
    }

    private func lastBody() async throws -> [String: Any] {
        let body = try #require(await api.sentRequests.last?.body)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    private let fall = SemesterForm(
        name: "Fall", institution: "UFRJ", startDay: "2026-08-01", endDay: "2026-12-15", rotationWeeks: 2)

    @Test func aNewSemesterPostsItsForm() async throws {
        await api.script([.reply(201, semesterJSON())])
        let semester = try await writes.save(fall, existing: nil)
        #expect(semester.name == "Fall" && semester.rotationWeeks == 2)
        #expect(await api.sentRequests.last?.path == "/api/v1/study/semesters/")
        let body = try await lastBody()
        #expect(body["start_date"] as? String == "2026-08-01" && body["rotation_weeks"] as? Int == 2)
        #expect(body.keys.contains("rotation_anchor") && body["rotation_anchor"] is NSNull)
    }

    @Test func anEditPatchesTheSameRecord() async throws {
        await api.script([.reply(201, semesterJSON()), .reply(200, semesterJSON(name: "Autumn"))])
        let semester = try await writes.save(fall, existing: nil)
        var renamed = fall
        renamed.name = "Autumn"
        try await writes.save(renamed, existing: semester)
        let sent = try #require(await api.sentRequests.last)
        #expect(sent.method == "PATCH" && sent.path == "/api/v1/study/semesters/\(semesterID)/")
        #expect(try context.fetch(FetchDescriptor<SemesterRecord>()).map(\.name) == ["Autumn"])
    }

    @Test func aDisciplineAndItsScheduleArePostedUnderTheirParents() async throws {
        context.insert(SemesterRecord(dto: try LibrarySample.semester()))
        await api.script([
            .reply(201, try Self.json(LibrarySample.discipline())), .reply(201, try Self.json(LibrarySample.schedule())),
        ])
        let discipline = try await writes.save(
            DisciplineForm(semesterID: semesterID, name: "Calculus", code: "MAT1", professor: "", color: "#3b82f6"),
            existing: nil)
        #expect(try await lastBody()["semester"] as? String == semesterID.lowercased())
        _ = try await writes.save(
            ClassScheduleForm(
                disciplineID: discipline.id, dayOfWeek: 0, startTime: "10:00:00", endTime: "11:40:00",
                classType: "lecture", location: "Room 1", rotationWeeksOn: [1]),
            existing: nil)
        let body = try await lastBody()
        #expect(body["discipline"] as? String == disciplineID.lowercased() && body["rotation_weeks_on"] as? [Int] == [1])
        #expect(await api.sentRequests.last?.path == "/api/v1/study/classschedules/")
    }

    @Test func deletingASemesterTakesItsTreeFromTheCache() async throws {
        context.insert(SemesterRecord(dto: try LibrarySample.semester()))
        context.insert(DisciplineRecord(dto: try LibrarySample.discipline()))
        context.insert(ClassScheduleRecord(dto: try LibrarySample.schedule()))
        context.insert(HolidayRecord(dto: try LibrarySample.holiday()))
        try context.save()
        await api.script([.reply(204, "")])
        let semester = try #require(try context.fetch(FetchDescriptor<SemesterRecord>()).first)
        try await writes.delete(semester)
        #expect(await api.sentRequests.last?.path == "/api/v1/study/semesters/\(semesterID)/")
        #expect(try context.fetchCount(FetchDescriptor<DisciplineRecord>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ClassScheduleRecord>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<HolidayRecord>()) == 0)
    }

    @Test func deletingADisciplineTakesItsSchedules() async throws {
        context.insert(DisciplineRecord(dto: try LibrarySample.discipline()))
        context.insert(ClassScheduleRecord(dto: try LibrarySample.schedule()))
        try context.save()
        await api.script([.reply(204, "")])
        try await writes.delete(try #require(try context.fetch(FetchDescriptor<DisciplineRecord>()).first))
        #expect(try context.fetchCount(FetchDescriptor<ClassScheduleRecord>()) == 0)
    }

    @Test func aHolidayIsPostedWithItsRange() async throws {
        await api.script([.reply(201, try Self.json(LibrarySample.holiday()))])
        _ = try await writes.save(
            HolidayForm(semesterID: semesterID, name: "Easter", startDay: "2026-04-03", endDay: "2026-04-10"),
            existing: nil)
        let body = try await lastBody()
        #expect(body["start_date"] as? String == "2026-04-03" && body["end_date"] as? String == "2026-04-10")
        #expect(await api.sentRequests.last?.path == "/api/v1/study/holidays/")
    }

    /// The server's reply for a sample record, as JSON text.
    private static func json(_ dto: some Encodable) throws -> String {
        String(bytes: try OmakaseJSON.encoder.encode(dto), encoding: .utf8) ?? ""
    }
}
