import Foundation
import OmakaseAPI

/// The outbox's decisions as pure functions (spec, Data flow -> Replay).
///
///     OutboxRules.classify(.success(response))   // .accepted / .retry / .park / .signedOut
public enum OutboxRules {
    public enum Outcome: Equatable, Sendable {
        case accepted(Data)
        case retry(String)
        case park(String)
        case signedOut
    }

    /// 1 s doubling, capped at 5 min.
    public static func backoff(afterAttempts attempts: Int) -> TimeInterval {
        min(pow(2, Double(max(attempts, 1) - 1)), 300)
    }

    public static func classify(_ result: Result<OutboxResponse, APIError>) -> Outcome {
        switch result {
        case .failure(.signedOut): return .signedOut
        case .failure(let error): return .retry(describe(error))
        case .success(let response): return classify(response)
        }
    }

    @MainActor
    public static func rewrite(_ entry: OutboxEntry, localID: String, serverID: String) {
        entry.path = entry.path.replacingOccurrences(of: localID, with: serverID)
        entry.body = entry.body.map { replacing(localID, with: serverID, in: $0) }
        if entry.subjectID == localID { entry.subjectID = serverID }
    }

    @MainActor
    public static func references(_ entry: OutboxEntry, localID: String) -> Bool {
        entry.path.contains(localID) || entry.body.map { text($0).contains(localID) } ?? false
    }

    private static func classify(_ response: OutboxResponse) -> Outcome {
        switch response.status {
        case 200..<300: return .accepted(response.body)
        case 429, 500...: return .retry("HTTP \(response.status)")
        default: return .park(detail(response.body) ?? "HTTP \(response.status)")
        }
    }

    private static func detail(_ body: Data) -> String? {
        let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        return object?["detail"] as? String
    }

    private static func describe(_ error: APIError) -> String {
        if case .transport(let reason) = error { return reason }
        return String(describing: error)
    }

    private static func text(_ body: Data) -> String { String(bytes: body, encoding: .utf8) ?? "" }

    private static func replacing(_ old: String, with new: String, in body: Data) -> Data {
        Data(text(body).replacingOccurrences(of: old, with: new).utf8)
    }
}
