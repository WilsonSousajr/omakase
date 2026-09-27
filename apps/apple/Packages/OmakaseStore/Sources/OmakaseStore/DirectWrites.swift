import Foundation
import OmakaseAPI
import SwiftData

/// The library's writes (#224): workspaces, projects, semesters, disciplines,
/// class schedules, holidays. Online-only (parent spec L136-139), so each one
/// is sent now, the cache takes the server's reply, and a failure is thrown to
/// the screen instead of queued.
///
///     let project = try await DirectWrites(api: api, context: context)
///         .save(ProjectRecord.self, "POST", "/api/v1/projects/", body: body)
@MainActor
public struct DirectWrites {
    public enum Failure: Error, Equatable, CustomStringConvertible {
        case offline
        case signedOut
        /// The server's own words, field by field.
        case rejected(String)

        public var description: String {
            switch self {
            case .offline: "Needs a connection."
            case .signedOut: "Signed out. Sign in again to save this."
            case .rejected(let message): message
            }
        }
    }

    private let api: any APIClient
    private let context: ModelContext

    public init(api: any APIClient, context: ModelContext) { (self.api, self.context) = (api, context) }

    /// A create (POST) or an update (PATCH/PUT) whose reply is the record.
    @discardableResult
    public func save<Record: LibraryCached>(
        _ type: Record.Type, _ method: String, _ path: String, body: Data
    ) async throws -> Record {
        let reply = try await send(method, path, body: body)
        let dto = try OmakaseJSON.decoder.decode(Record.DTO.self, from: reply)
        let record = try cached(Record.self, id: dto.id.uuidString) ?? insert(Record(dto: dto))
        record.apply(dto)
        try context.save()
        return record
    }

    public func delete<Record: LibraryCached>(_ record: Record, path: String) async throws {
        _ = try await send("DELETE", path, body: nil)
        context.delete(record)
        try context.save()
    }

    /// Sends one request now; the reply's body on 2xx, a `Failure` otherwise.
    public func send(_ method: String, _ path: String, body: Data?) async throws -> Data {
        let request = OutboxRequest(method: method, path: path, body: body, idempotencyKey: UUID().uuidString)
        let response: OutboxResponse
        do {
            response = try await api.send(request)
        } catch APIError.signedOut {
            throw Failure.signedOut
        } catch {
            throw Failure.offline
        }
        guard (200..<300).contains(response.status) else {
            throw Failure.rejected(ServerMessage.read(response.body, status: response.status))
        }
        return response.body
    }

    private func cached<Record: LibraryCached>(_ type: Record.Type, id: String) throws -> Record? {
        try context.fetch(FetchDescriptor<Record>()).first { $0.id == id }
    }

    private func insert<Record: LibraryCached>(_ record: Record) -> Record {
        context.insert(record)
        return record
    }
}

/// A refusal in words: DRF's "detail", or its field errors as
/// "field: message", sorted so the text is stable.
public enum ServerMessage {
    public static func read(_ body: Data, status: Int) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return "HTTP \(status)"
        }
        if let detail = object["detail"] as? String { return detail }
        let fields = object.keys.sorted().compactMap { key in fieldMessage(key, object[key]) }
        return fields.isEmpty ? "HTTP \(status)" : fields.joined(separator: " ")
    }

    private static func fieldMessage(_ key: String, _ value: Any?) -> String? {
        if let messages = value as? [String] { return "\(key): \(messages.joined(separator: " "))" }
        if let message = value as? String { return "\(key): \(message)" }
        return nil
    }
}
