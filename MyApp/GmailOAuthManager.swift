import AuthenticationServices
import CryptoKit
import Foundation
import Security

public enum GmailConfiguration {
    // Replace this with the iOS OAuth client ID from Google Cloud.
    public static let clientID = "706463254809-chqd5vv0lqs4k6ebtnn7o4tnqb7dpan1.apps.googleusercontent.com"
    public static let scope = "https://www.googleapis.com/auth/gmail.modify"
    public static let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
    public static let authorizationURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!

    public static var redirectScheme: String {
        guard let separator = clientID.firstIndex(of: ".") else { return "" }
        return "com.googleusercontent.apps." + clientID[..<separator]
    }

    public static var redirectURI: String {
        "\(redirectScheme):/oauthredirect"
    }
}

public enum GmailAuthError: LocalizedError {
    case notConfigured
    case cancelled
    case invalidResponse
    case missingAccessToken
    case tokenExchangeFailed

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Gmail is not configured yet. Add the Google Cloud iOS OAuth client ID."
        case .cancelled:
            return "Google sign-in was cancelled."
        case .invalidResponse:
            return "Google returned an invalid sign-in response."
        case .missingAccessToken:
            return "Google did not return an access token."
        case .tokenExchangeFailed:
            return "Swipey could not complete Gmail sign-in."
        }
    }
}

@MainActor
public final class GmailOAuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    public private(set) var accessToken: String?
    private var authenticationSession: ASWebAuthenticationSession?
    private let refreshTokenKey = "Swipey.Gmail.RefreshToken"
    private var refreshToken: String?

    public override init() {
        super.init()
        refreshToken = readRefreshToken()
    }

    public var isSignedIn: Bool {
        accessToken != nil
    }

    public var hasStoredCredentials: Bool {
        accessToken != nil || refreshToken != nil
    }

    public func signIn() async throws {
        guard !GmailConfiguration.clientID.isEmpty else {
            throw GmailAuthError.notConfigured
        }

        let state = UUID().uuidString
        let codeVerifier = makeCodeVerifier()
        let codeChallenge = makeCodeChallenge(for: codeVerifier)

        guard let authorizationURL = makeAuthorizationURL(
            state: state,
            codeChallenge: codeChallenge
        ) else {
            throw GmailAuthError.notConfigured
        }

        let callbackURL = try await authenticate(using: authorizationURL)
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value,
              returnedState == state,
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw GmailAuthError.invalidResponse
        }

        try await exchangeCodeForTokens(code, codeVerifier: codeVerifier)
    }

    public func signOut() {
        accessToken = nil
        refreshToken = nil
        deleteRefreshToken()
    }

    public func validAccessToken() async throws -> String {
        if let accessToken {
            return accessToken
        }

        if let refreshToken {
            try await refreshAccessToken(refreshToken)
            guard let accessToken else {
                throw GmailAuthError.missingAccessToken
            }
            return accessToken
        }

        throw GmailAuthError.missingAccessToken
    }

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }

    private func makeAuthorizationURL(state: String, codeChallenge: String) -> URL? {
        var components = URLComponents(url: GmailConfiguration.authorizationURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: GmailConfiguration.clientID),
            URLQueryItem(name: "redirect_uri", value: GmailConfiguration.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GmailConfiguration.scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        return components?.url
    }

    private func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private func makeCodeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private func authenticate(using url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: GmailConfiguration.redirectScheme
            ) { [weak self] callbackURL, error in
                self?.authenticationSession = nil

                if let error {
                    if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                        continuation.resume(throwing: GmailAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: GmailAuthError.invalidResponse)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.authenticationSession = session

            guard session.start() else {
                self.authenticationSession = nil
                continuation.resume(throwing: GmailAuthError.invalidResponse)
                return
            }
        }
    }

    private func exchangeCodeForTokens(_ code: String, codeVerifier: String) async throws {
        var request = URLRequest(url: GmailConfiguration.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "code": code,
            "client_id": GmailConfiguration.clientID,
            "redirect_uri": GmailConfiguration.redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ]
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw GmailAuthError.tokenExchangeFailed
        }

        let tokens = try JSONDecoder().decode(GmailTokenResponse.self, from: data)
        guard let accessToken = tokens.accessToken as String? else {
            throw GmailAuthError.missingAccessToken
        }

        self.accessToken = accessToken
        if let refreshToken = tokens.refreshToken {
            self.refreshToken = refreshToken
            saveRefreshToken(refreshToken)
        }
    }

    private func refreshAccessToken(_ refreshToken: String) async throws {
        var request = URLRequest(url: GmailConfiguration.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": GmailConfiguration.clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw GmailAuthError.tokenExchangeFailed
        }

        let tokens = try JSONDecoder().decode(GmailTokenResponse.self, from: data)
        self.accessToken = tokens.accessToken
    }

    private func saveRefreshToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: refreshTokenKey,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func readRefreshToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: refreshTokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func deleteRefreshToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: refreshTokenKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
