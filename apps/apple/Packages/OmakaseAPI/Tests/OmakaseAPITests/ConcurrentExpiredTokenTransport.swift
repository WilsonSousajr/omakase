import Foundation

@testable import OmakaseAPI

/// Answers a request carrying the expired access token with 401 only once
/// `wave` such requests have all arrived, forcing the real race #276 fixes:
/// every concurrent caller must see 401 before any of them can have started
/// a refresh. Without that gate, a fast in-process fake could let one caller
/// finish its whole refresh-and-retry before a sibling even sends its first
/// request, masking the bug.
actor ConcurrentExpiredTokenTransport: HTTPTransport {
    private let expired = "a1"
    private let refreshed = "a2"
    private let meBody: Data
    private let wave: Int
    private var arrived = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var refreshCount = 0

    init(meBody: Data, wave: Int) {
        (self.meBody, self.wave) = (meBody, wave)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if request.url?.path() == "/api/v1/auth/token/refresh/" {
            refreshCount += 1
            return reply(200, Data(#"{"access":"a2"}"#.utf8), request.url!)
        }
        if request.value(forHTTPHeaderField: "Authorization") == "Bearer \(expired)" {
            await joinWave()
            return reply(401, Data(#"{"detail":"expired"}"#.utf8), request.url!)
        }
        guard request.value(forHTTPHeaderField: "Authorization") == "Bearer \(refreshed)" else {
            throw URLError(.userAuthenticationRequired)
        }
        return reply(200, meBody, request.url!)
    }

    /// Every caller waits here until the whole wave has arrived, then all resume together.
    private func joinWave() async {
        arrived += 1
        if arrived >= wave {
            for waiter in waiters { waiter.resume() }
            waiters.removeAll()
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func reply(_ status: Int, _ body: Data, _ url: URL) -> (Data, HTTPURLResponse) {
        (body, HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}
