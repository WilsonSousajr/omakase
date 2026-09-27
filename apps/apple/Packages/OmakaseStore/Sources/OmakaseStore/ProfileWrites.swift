import Foundation
import OmakaseAPI
import SwiftData

/// A Settings edit (#228): nil leaves a field as it is; a reminder is set, or
/// cleared with an explicit null, which turns it off (#127).
public struct ProfileChange: Equatable, Sendable, Encodable {
    public typealias Clearable = TaskEdit.Clearable

    public var workMinutes: Int?
    public var shortBreakMinutes: Int?
    public var longBreakMinutes: Int?
    public var beforeLongBreak: Int?
    public var workGoalHours: Double?
    public var studyGoalHours: Double?
    public var blockReminderMinutes: Clearable<Int>?
    public var shutdownReminderTime: Clearable<String>?
    /// "monday" or "sunday".
    public var weekStartsOn: String?

    public init(
        workMinutes: Int? = nil, shortBreakMinutes: Int? = nil, longBreakMinutes: Int? = nil,
        beforeLongBreak: Int? = nil, workGoalHours: Double? = nil, studyGoalHours: Double? = nil,
        blockReminderMinutes: Clearable<Int>? = nil, shutdownReminderTime: Clearable<String>? = nil,
        weekStartsOn: String? = nil
    ) {
        (self.workMinutes, self.shortBreakMinutes, self.longBreakMinutes) = (
            workMinutes, shortBreakMinutes, longBreakMinutes
        )
        (self.beforeLongBreak, self.workGoalHours, self.studyGoalHours) = (
            beforeLongBreak, workGoalHours, studyGoalHours
        )
        (self.blockReminderMinutes, self.shutdownReminderTime, self.weekStartsOn) = (
            blockReminderMinutes, shutdownReminderTime, weekStartsOn
        )
    }

    public var isEmpty: Bool { self == ProfileChange() }

    private enum CodingKeys: String, CodingKey {
        case workMinutes = "pomodoro_work_minutes"
        case shortBreakMinutes = "pomodoro_short_break_minutes"
        case longBreakMinutes = "pomodoro_long_break_minutes"
        case beforeLongBreak = "pomodoros_before_long_break"
        case workGoalHours = "daily_work_goal_hours"
        case studyGoalHours = "daily_study_goal_hours"
        case blockReminderMinutes = "block_reminder_minutes"
        case shutdownReminderTime = "shutdown_reminder_time"
        case weekStartsOn = "week_starts_on"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(workMinutes, forKey: .workMinutes)
        try container.encodeIfPresent(shortBreakMinutes, forKey: .shortBreakMinutes)
        try container.encodeIfPresent(longBreakMinutes, forKey: .longBreakMinutes)
        try container.encodeIfPresent(beforeLongBreak, forKey: .beforeLongBreak)
        try container.encodeIfPresent(workGoalHours, forKey: .workGoalHours)
        try container.encodeIfPresent(studyGoalHours, forKey: .studyGoalHours)
        try container.encodeIfPresent(weekStartsOn, forKey: .weekStartsOn)
        try Self.encode(blockReminderMinutes, .blockReminderMinutes, in: &container)
        try Self.encode(shutdownReminderTime, .shutdownReminderTime, in: &container)
    }

    /// Absent when unchanged, the value when set, an explicit null when cleared.
    private static func encode<Value: Encodable>(
        _ change: Clearable<Value>?, _ key: CodingKeys, in container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        guard let change else { return }
        if let value = change.value {
            try container.encode(value, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }
}

/// Saves a Settings edit to the profile, online (#228): the PATCH goes now
/// through `DirectWrites`, and the server's reply replaces the cached profile.
///
///     try await ProfileWrites(api: api, context: context).save(ProfileChange(workMinutes: 50))
@MainActor
public struct ProfileWrites {
    private let api: any APIClient
    private let context: ModelContext

    public init(api: any APIClient, context: ModelContext) { (self.api, self.context) = (api, context) }

    public func save(_ change: ProfileChange) async throws {
        guard !change.isEmpty else { return }
        let body = try JSONEncoder().encode(change)
        let writes = DirectWrites(api: api, context: context)
        let reply = try await writes.send("PATCH", "/api/v1/auth/profile/", body: body)
        let dto = try OmakaseJSON.decoder.decode(ProfileDTO.self, from: reply)
        if let profile = try context.fetch(FetchDescriptor<ProfileRecord>()).first {
            profile.apply(dto)
        } else {
            context.insert(ProfileRecord(dto: dto))
        }
        try context.save()
    }
}
