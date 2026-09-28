import Foundation
import OmakaseAPI

/// A named fake `HTTPTransport` for #276: answers every one of `DaySync`'s
/// seven concurrent reads with an empty day, and 401s any request still
/// carrying the expired token - so a real `OmakaseAPIClient` + `DaySync` +
/// `SyncCoordinator` can be exercised without a network. Gates the 401 the
/// same way `ConcurrentExpiredTokenTransport` does in OmakaseAPITests: only
/// answering once the whole wave has arrived, so a fast in-process fake
/// can't mask the race by letting one caller finish before another even
/// sends its first request.
actor ExpiredLaunchTokenTransport: HTTPTransport {
    private let expired = "expired"
    private let refreshed = "fresh"
    /// DaySync.refresh() always fires exactly these seven reads at once.
    private let wave = 7
    private var arrived = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var refreshCount = 0

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if request.url?.path() == "/api/v1/auth/token/refresh/" {
            refreshCount += 1
            return reply(200, Data(#"{"access":"fresh"}"#.utf8), request.url!)
        }
        if request.value(forHTTPHeaderField: "Authorization") == "Bearer \(expired)" {
            await joinWave()
            return reply(401, Data(#"{"detail":"expired"}"#.utf8), request.url!)
        }
        guard request.value(forHTTPHeaderField: "Authorization") == "Bearer \(refreshed)" else {
            throw URLError(.userAuthenticationRequired)
        }
        return reply(200, try body(for: request.url!), request.url!)
    }

    /// An empty day for every read `DaySync.refresh()` makes, DRF-paginated
    /// where the real endpoint is.
    private func body(for url: URL) throws -> Data {
        switch url.path() {
        case "/api/v1/auth/profile/":
            return try OmakaseJSON.encoder.encode(ProfileDTO.make())
        case "/api/v1/stats/workload/":
            return try OmakaseJSON.encoder.encode(WorkloadDTO.make(day: "2026-03-07"))
        case "/api/v1/tasks/carried-over/":
            return Data("[]".utf8)
        default:
            return Data(#"{"count":0,"next":null,"previous":null,"results":[]}"#.utf8)
        }
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
