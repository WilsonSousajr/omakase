import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// Settings writes the profile online (#228; parent spec L136-139): only the
/// fields that changed, an explicit null to turn a reminder off, and the
/// server's copy cached from the reply.
@MainActor
struct ProfileWritesTests {
    let container: ModelContainer
    let api = FakeAPIClient()

    init() throws { container = try StoreSchema.container(inMemory: true) }

    private var context: ModelContext { container.mainContext }
    private var writes: ProfileWrites { ProfileWrites(api: api, context: context) }

    private func replyJSON(block: String = "5", shutdown: String = "null", week: String = "monday") -> String {
        """
        {"pomodoro_work_minutes":50,"pomodoro_short_break_minutes":5,"pomodoro_long_break_minutes":15,
         "pomodoros_before_long_break":4,"daily_work_goal_hours":"6.5","daily_study_goal_hours":"4.0",
         "block_reminder_minutes":\(block),"shutdown_reminder_time":\(shutdown),
         "timezone":"UTC","week_starts_on":"\(week)"}
        """
    }

    private func sentBody() async throws -> [String: Any] {
        let body = try #require(await api.sentRequests.last?.body)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    @Test func onlyTheChangedFieldsAreSent() async throws {
        await api.script([.reply(200, replyJSON())])
        try await writes.save(ProfileChange(workMinutes: 50, workGoalHours: 6.5))
        let sent = try #require(await api.sentRequests.last)
        #expect(sent.method == "PATCH" && sent.path == "/api/v1/auth/profile/")
        let body = try await sentBody()
        #expect(Set(body.keys) == ["pomodoro_work_minutes", "daily_work_goal_hours"])
        #expect(body["pomodoro_work_minutes"] as? Int == 50 && body["daily_work_goal_hours"] as? Double == 6.5)
    }

    @Test func turningAReminderOffSendsAnExplicitNull() async throws {
        await api.script([.reply(200, replyJSON(block: "null"))])
        try await writes.save(ProfileChange(blockReminderMinutes: .clear))
        let body = try await sentBody()
        #expect(body.keys.contains("block_reminder_minutes") && body["block_reminder_minutes"] is NSNull)
    }

    @Test func theRepliedProfileIsCached() async throws {
        await api.script([.reply(200, replyJSON(shutdown: "\"21:30:00\"", week: "sunday"))])
        try await writes.save(ProfileChange(shutdownReminderTime: .set("21:30:00"), weekStartsOn: "sunday"))
        let profile = try #require(try context.fetch(FetchDescriptor<ProfileRecord>()).first)
        #expect(profile.workMinutes == 50 && profile.workGoalHours == 6.5)
        #expect(profile.shutdownReminderTime == "21:30:00" && profile.weekStartsOn == "sunday")
    }

    @Test func anEmptyChangeSendsNothing() async throws {
        try await writes.save(ProfileChange())
        #expect(await api.sentRequests.isEmpty)
    }

    @Test func aRefusalCarriesTheServersMessage() async throws {
        await api.script([.reply(400, #"{"block_reminder_minutes":["block_reminder_minutes 121 is outside 1-120."]}"#)])
        await #expect(throws: DirectWrites.Failure.rejected("block_reminder_minutes: block_reminder_minutes 121 is outside 1-120.")) {
            try await writes.save(ProfileChange(blockReminderMinutes: .set(121)))
        }
    }
}
