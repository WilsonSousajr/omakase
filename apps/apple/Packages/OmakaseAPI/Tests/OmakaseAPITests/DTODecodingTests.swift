import Foundation
import Testing

@testable import OmakaseAPI

struct DTODecodingTests {
    @Test func decodesTheLoginResponse() throws {
        let pair = try OmakaseJSON.decoder.decode(TokenPairDTO.self, from: Fixture.data("auth_google"))
        #expect(!pair.access.isEmpty && !pair.refresh.isEmpty)
        #expect(pair.user.email == "ada@example.com")
    }

    @Test func decodesARefreshWithoutARotatedRefreshToken() throws {
        // SIMPLE_JWT does not rotate refresh tokens: the response is access only.
        let token = try OmakaseJSON.decoder.decode(AccessTokenDTO.self, from: Fixture.data("token_refresh"))
        #expect(!token.access.isEmpty)
    }

    @Test func decodesMe() throws {
        let user = try OmakaseJSON.decoder.decode(UserDTO.self, from: Fixture.data("auth_me"))
        #expect(user.id > 0 && user.avatarColor.hasPrefix("#"))
    }

    @Test func decodesTodaysPage() throws {
        let page = try OmakaseJSON.decoder.decode(Page<TaskDTO>.self, from: Fixture.data("tasks_today"))
        let task = try #require(page.results.first)
        #expect(page.count == 1)
        #expect(task.scheduledDate?.string == "2026-03-07")
        #expect(task.tags.count == 1 && task.isCompleted == false && task.completedAt == nil)
    }

    @Test func decodesACompletedTask() throws {
        let task = try OmakaseJSON.decoder.decode(TaskDTO.self, from: Fixture.data("task_patch"))
        #expect(task.isCompleted && task.completedAt != nil)
    }

    @Test func decodesMicrosecondAndWholeSecondDatetimes() throws {
        // Review Focus 3: DRF emits microseconds; some producers emit none.
        let json = #"["2026-03-07T12:00:00.123456Z", "2026-03-07T12:00:00Z", "2026-03-07T12:00:00.1+00:00"]"#
        let dates = try OmakaseJSON.decoder.decode([Date].self, from: Data(json.utf8))
        #expect(dates[1].timeIntervalSince1970 == 1_772_884_800)
        #expect(abs(dates[0].timeIntervalSince(dates[1]) - 0.123) < 0.001)
    }

    @Test func aMalformedDatetimeNamesTheValue() {
        #expect {
            try OmakaseJSON.decoder.decode([Date].self, from: Data(#"["07/03/2026"]"#.utf8))
        } throws: { error in
            String(describing: error).contains("\"07/03/2026\" is not an ISO-8601 datetime")
        }
    }

    @Test func encodesSnakeCaseWithSortedKeys() throws {
        struct Body: Encodable {
            let isCompleted: Bool
            let codeVerifier: String
        }
        let data = try OmakaseJSON.encoder.encode(Body(isCompleted: true, codeVerifier: "v"))
        #expect(String(bytes: data, encoding: .utf8) == #"{"code_verifier":"v","is_completed":true}"#)
    }
}
