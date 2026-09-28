import Testing

@testable import OmakaseFeatures

struct FakeAuthenticator: GoogleAuthenticating {
    struct Cancelled: Error {}
    let token: String?

    func idToken() async throws -> String {
        guard let token else { throw Cancelled() }
        return token
    }
}

@MainActor
struct SignInModelTests {
    @Test func successEndsSignedInWithTheEmail() async {
        let model = SignInModel(
            authenticator: FakeAuthenticator(token: "id-token"),
            signIn: { token in token == "id-token" ? "ada@example.com" : "wrong token" })
        await model.signIn()
        #expect(model.state == .signedIn("ada@example.com"))
    }

    @Test func aCancelledOrFailedSignInIsShownAndRetryable() async {
        let model = SignInModel(authenticator: FakeAuthenticator(token: nil), signIn: { _ in "" })
        await model.signIn()
        guard case .failed(let message) = model.state else {
            Issue.record("expected failed, got \(model.state)")
            return
        }
        #expect(message.hasPrefix("Sign-in didn't finish"))
    }
}
