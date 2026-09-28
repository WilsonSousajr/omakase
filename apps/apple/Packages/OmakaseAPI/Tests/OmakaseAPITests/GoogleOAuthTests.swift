import CryptoKit
import Foundation
import Testing

@testable import OmakaseAPI

struct GoogleOAuthTests {
    private let oauth = GoogleOAuth(clientID: "123-abc.apps.googleusercontent.com")
    private let verifier = String(repeating: "v", count: 43)

    @Test func callbackSchemeIsTheReversedClientID() {
        #expect(oauth.callbackScheme == "com.googleusercontent.apps.123-abc")
        #expect(oauth.redirectURI == "com.googleusercontent.apps.123-abc:/oauthredirect")
    }

    @Test func authorizationURLCarriesPKCEAndState() throws {
        let auth = oauth.authorization()
        let items = try #require(URLComponents(url: auth.url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        #expect(auth.url.host() == "accounts.google.com")
        #expect(query["response_type"] == "code" && query["code_challenge_method"] == "S256")
        #expect(query["scope"] == "openid email profile" && query["state"] == auth.state)
        let expected = Data(SHA256.hash(data: Data(auth.verifier.utf8))).base64URL
        #expect(query["code_challenge"] == expected)
        #expect((43...128).contains(auth.verifier.count))
    }

    @Test func callbackYieldsTheCodeOnlyForTheExpectedState() throws {
        let callback = URL(string: "com.googleusercontent.apps.123-abc:/oauthredirect?code=4%2Fabc&state=s1")!
        #expect(try oauth.code(from: callback, expecting: "s1") == "4/abc")
        #expect(throws: GoogleOAuthError.stateMismatch) { try oauth.code(from: callback, expecting: "s2") }
    }

    @Test func aDeniedConsentIsAnError() {
        let callback = URL(string: "com.googleusercontent.apps.123-abc:/oauthredirect?error=access_denied&state=s1")!
        #expect(throws: GoogleOAuthError.denied("access_denied")) { try oauth.code(from: callback, expecting: "s1") }
    }

    @Test func aCallbackWithoutACodeIsAnError() {
        let callback = URL(string: "com.googleusercontent.apps.123-abc:/oauthredirect?state=s1")!
        #expect(throws: GoogleOAuthError.missingCode) { try oauth.code(from: callback, expecting: "s1") }
    }

    @Test func exchangePostsTheVerifierAndReturnsTheIDToken() async throws {
        let transport = FakeHTTPTransport([FakeHTTPTransport.json(200, #"{"id_token":"eyJ.id.token"}"#)])
        let token = try await oauth.exchange(code: "4/abc", verifier: verifier, transport: transport)
        #expect(token == "eyJ.id.token")
        let request = try #require(await transport.sent.first)
        #expect(request.url?.absoluteString == "https://oauth2.googleapis.com/token")
        let form = String(bytes: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        #expect(form.contains("grant_type=authorization_code") && form.contains("code_verifier=\(verifier)"))
    }

    @Test func exchangeToleratesGooglesFullTokenResponse() async throws {
        let body = #"{"access_token":"x","expires_in":3599,"id_token":"eyJ.id.token","token_type":"Bearer"}"#
        let transport = FakeHTTPTransport([FakeHTTPTransport.json(200, body)])
        #expect(try await oauth.exchange(code: "c", verifier: verifier, transport: transport) == "eyJ.id.token")
    }

    @Test func aFailedExchangeReportsTheStatus() async {
        let transport = FakeHTTPTransport([FakeHTTPTransport.json(400, #"{"error":"invalid_grant"}"#)])
        await #expect(throws: GoogleOAuthError.tokenExchange(status: 400)) {
            try await oauth.exchange(code: "c", verifier: verifier, transport: transport)
        }
    }
}
