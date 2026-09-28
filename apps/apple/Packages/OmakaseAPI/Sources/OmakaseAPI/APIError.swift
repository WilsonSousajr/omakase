import Foundation

public enum APIError: Error, Equatable, Sendable {
    /// No valid tokens: refresh failed or never signed in. The outbox pauses.
    case signedOut
    /// The request never got an HTTP answer. The outbox retries.
    case transport(String)
    /// The server answered with a non-2xx status; `detail` is its message.
    case http(status: Int, detail: String)
    /// A 2xx body that does not match the DTO: a contract break.
    case decoding(String)
}
