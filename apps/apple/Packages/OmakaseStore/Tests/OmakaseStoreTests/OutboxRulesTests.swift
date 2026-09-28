import Foundation
import OmakaseAPI
import Testing

@testable import OmakaseStore

struct OutboxRulesTests {
    @Test(arguments: [(1, 1.0), (2, 2.0), (3, 4.0), (9, 256.0), (10, 300.0), (50, 300.0)])
    func backoffDoublesFromOneSecondAndCapsAtFiveMinutes(attempts: Int, seconds: Double) {
        #expect(OutboxRules.backoff(afterAttempts: attempts) == seconds)
    }

    @Test func classifiesEveryAnswer() {
        let body = Data(#"{"detail":"no"}"#.utf8)
        let reply = { (status: Int) in
            Result<OutboxResponse, APIError>.success(OutboxResponse(status: status, body: body))
        }
        #expect(OutboxRules.classify(reply(201)) == .accepted(body))
        #expect(OutboxRules.classify(reply(503)) == .retry("HTTP 503"))
        #expect(OutboxRules.classify(reply(429)) == .retry("HTTP 429"))
        #expect(OutboxRules.classify(reply(400)) == .park("no"))
        #expect(OutboxRules.classify(.failure(.transport("offline"))) == .retry("offline"))
        #expect(OutboxRules.classify(.failure(.signedOut)) == .signedOut)
    }

    @Test func aRejectionWithoutADetailParksWithItsStatus() {
        let reply = OutboxResponse(status: 422, body: Data(#"{"title":["required"]}"#.utf8))
        #expect(OutboxRules.classify(.success(reply)) == .park("HTTP 422"))
    }

    @Test @MainActor func rewritesAPlaceholderInPathAndBody() {
        let entry = OutboxEntry(
            sequence: 2, method: "PATCH", path: "/api/v1/tasks/local-1/",
            body: Data(#"{"parent":"local-1"}"#.utf8), subjectID: "local-1")
        OutboxRules.rewrite(entry, localID: "local-1", serverID: "9F1C")
        #expect(entry.path == "/api/v1/tasks/9F1C/" && entry.subjectID == "9F1C")
        #expect(String(bytes: entry.body ?? Data(), encoding: .utf8) == #"{"parent":"9F1C"}"#)
        #expect(OutboxRules.references(entry, localID: "local-1") == false)
    }

    @Test func aDeleteWhoseTargetIsAlreadyGoneIsAccepted() {
        // #201: a block deleted elsewhere must not park its delete forever.
        let gone = Result<OutboxResponse, APIError>.success(OutboxResponse(status: 404, body: Data()))
        #expect(OutboxRules.classify(gone, method: "DELETE") == .accepted(Data()))
        #expect(OutboxRules.classify(gone, method: "PATCH") == .park("HTTP 404"))
        #expect(OutboxRules.classify(.failure(.transport("offline")), method: "DELETE") == .retry("offline"))
    }

    @Test @MainActor func dependentsFollowACreateThatDependsOnACreate() {
        // #201: a block created on a captured task, then moved, all offline.
        let task = OutboxEntry(
            sequence: 1, method: "POST", path: "/api/v1/tasks/", body: nil, subjectID: "local-t",
            createsLocalID: "local-t")
        let block = OutboxEntry(
            sequence: 2, method: "POST", path: "/api/v1/timeblocks/", body: Data(#"{"task":"local-t"}"#.utf8),
            subjectID: "local-b", createsLocalID: "local-b")
        let move = OutboxEntry(
            sequence: 3, method: "PATCH", path: "/api/v1/timeblocks/local-b/", body: nil, subjectID: "local-b")
        let other = OutboxEntry(sequence: 4, method: "PATCH", path: "/api/v1/tasks/t9/", body: nil, subjectID: "t9")
        let found = OutboxRules.dependents(of: task, among: [task, move, other, block])
        #expect(found.map(\.sequence) == [2, 3])
    }
}
