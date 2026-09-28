import Observation

/// Produces a Google ID token; the app target implements it with
/// ASWebAuthenticationSession, tests with a named fake.
public protocol GoogleAuthenticating: Sendable {
    func idToken() async throws -> String
}

/// The sign-in screen's state. Features never sees the API: the app target
/// passes `signIn`, which exchanges the ID token and returns the user's email.
@MainActor @Observable
public final class SignInModel {
    public enum State: Equatable {
        case idle
        case working
        case signedIn(String)
        case failed(String)
    }

    public private(set) var state: State = .idle
    private let authenticator: any GoogleAuthenticating
    private let signInWithToken: (String) async throws -> String

    public init(authenticator: any GoogleAuthenticating, signIn: @escaping (String) async throws -> String) {
        (self.authenticator, signInWithToken) = (authenticator, signIn)
    }

    public func signIn() async {
        state = .working
        do {
            state = .signedIn(try await signInWithToken(try await authenticator.idToken()))
        } catch {
            state = .failed("Sign-in didn't finish: \(error.localizedDescription)")
        }
    }
}
