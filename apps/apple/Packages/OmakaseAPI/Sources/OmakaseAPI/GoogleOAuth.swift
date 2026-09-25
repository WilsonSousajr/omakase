import CryptoKit
import Foundation

public enum GoogleOAuthError: Error, Equatable, Sendable {
    case stateMismatch
    case denied(String)
    case missingCode
    case tokenExchange(status: Int)
}

public struct GoogleAuthorization: Sendable {
    public let url: URL
    public let verifier: String
    public let state: String
}

/// Google OAuth for a native client: authorization code + PKCE, no secret.
/// The ID token it yields goes to `APIClient.signIn(googleIDToken:)`.
///
///     let auth = GoogleOAuth(clientID: id).authorization()   // open auth.url
public struct GoogleOAuth: Sendable {
    public let clientID: String
    public init(clientID: String) { self.clientID = clientID }

    public var callbackScheme: String {
        "com.googleusercontent.apps." + clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
    }

    public var redirectURI: String { callbackScheme + ":/oauthredirect" }

    public func authorization() -> GoogleAuthorization {
        let verifier = Self.randomURLSafe(bytes: 48)
        let state = Self.randomURLSafe(bytes: 16)
        var parts = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        parts.queryItems = [
            .init(name: "client_id", value: clientID), .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"), .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: Data(SHA256.hash(data: Data(verifier.utf8))).base64URL),
            .init(name: "code_challenge_method", value: "S256"), .init(name: "state", value: state),
        ]
        return GoogleAuthorization(url: parts.url!, verifier: verifier, state: state)
    }

    public func code(from callback: URL, expecting state: String) throws -> String {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let value = { (name: String) in items.first { $0.name == name }?.value }
        guard value("state") == state else { throw GoogleOAuthError.stateMismatch }
        if let error = value("error") { throw GoogleOAuthError.denied(error) }
        guard let code = value("code") else { throw GoogleOAuthError.missingCode }
        return code
    }

    public func exchange(code: String, verifier: String, transport: any HTTPTransport) async throws -> String {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.form([
            "client_id": clientID, "code": code, "code_verifier": verifier,
            "grant_type": "authorization_code", "redirect_uri": redirectURI,
        ])
        let (data, response) = try await transport.send(request)
        guard response.statusCode == 200, let token = try? JSONDecoder().decode(TokenResponse.self, from: data)
        else { throw GoogleOAuthError.tokenExchange(status: response.statusCode) }
        return token.idToken
    }

    /// Only the field we use; Google's response also carries numbers (`expires_in`).
    private struct TokenResponse: Decodable {
        let idToken: String
        enum CodingKeys: String, CodingKey { case idToken = "id_token" }
    }

    private static func form(_ fields: [String: String]) -> Data {
        var parts = URLComponents()
        parts.queryItems = fields.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return Data((parts.percentEncodedQuery ?? "").utf8)
    }

    private static func randomURLSafe(bytes count: Int) -> String {
        var generator = SystemRandomNumberGenerator()
        return Data((0..<count).map { _ in UInt8.random(in: .min ... .max, using: &generator) }).base64URL
    }
}

extension Data {
    /// RFC 4648 base64url without padding, as PKCE requires.
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
