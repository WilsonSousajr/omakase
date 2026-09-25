import Foundation

@testable import OmakaseAPI

/// Replays scripted responses in order and records every request sent.
actor FakeHTTPTransport: HTTPTransport {
    struct Reply: Sendable {
        let status: Int
        let body: Data
    }

    private var replies: [Result<Reply, URLError>]
    private(set) var sent: [URLRequest] = []

    init(_ replies: [Result<Reply, URLError>]) { self.replies = replies }

    static func json(_ status: Int, _ body: String) -> Result<Reply, URLError> {
        .success(Reply(status: status, body: Data(body.utf8)))
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        sent.append(request)
        guard !replies.isEmpty else { throw URLError(.cannotConnectToHost) }
        let reply = try replies.removeFirst().get()
        let response = HTTPURLResponse(
            url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: nil)!
        return (reply.body, response)
    }
}
