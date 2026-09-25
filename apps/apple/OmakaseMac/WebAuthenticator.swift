import AppKit
import AuthenticationServices
import OmakaseAPI
import OmakaseFeatures

/// Runs Google's consent page in ASWebAuthenticationSession and returns the
/// ID token (spec, Data flow -> Auth). Thin glue: the testable parts are
/// OmakaseAPI.GoogleOAuth.
@MainActor
final class WebAuthenticator: NSObject, GoogleAuthenticating, ASWebAuthenticationPresentationContextProviding {
    private let oauth: GoogleOAuth
    /// Held so the session lives until it calls back; a local could be released first.
    private var session: ASWebAuthenticationSession?

    init(clientID: String) { oauth = GoogleOAuth(clientID: clientID) }

    nonisolated func idToken() async throws -> String {
        let auth = oauth.authorization()
        let callback = try await present(auth.url)
        let code = try oauth.code(from: callback, expecting: auth.state)
        return try await oauth.exchange(code: code, verifier: auth.verifier, transport: URLSessionTransport())
    }

    private func present(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let complete: (URL?, (any Error)?) -> Void = { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error ?? URLError(.cancelled))
                }
            }
            let callback = ASWebAuthenticationSession.Callback.customScheme(oauth.callbackScheme)
            let session = ASWebAuthenticationSession(url: url, callback: callback, completionHandler: complete)
            session.presentationContextProvider = self
            self.session = session
            // start() returns false without ever calling back (an empty client
            // ID, no window to anchor to); without this the button hangs (review I6).
            guard session.start() else {
                let reason = "the sign-in window could not open; is OMAKASE_GOOGLE_CLIENT_ID set?"
                complete(nil, GoogleOAuthError.denied(reason))
                return
            }
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor() }
    }
}
