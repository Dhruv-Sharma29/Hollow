import Foundation

/// The client Hollow signs in with (from Google's downloaded JSON).
public struct OAuthClient: Sendable {
    public let id: String
    public let secret: String
    public init(id: String, secret: String) { self.id = id; self.secret = secret }
}

/// A Google access token and when it stops working.
public struct AccessToken: Sendable, Equatable {
    public let value: String
    public let expiry: Date
    public init(value: String, expiry: Date) { self.value = value; self.expiry = expiry }
}

/// Hands out a valid access token, refreshing it with the refresh token when it's about to expire.
/// An actor so concurrent requests share one refresh instead of each starting their own.
public actor TokenProvider {
    private let client: OAuthClient
    private let refreshToken: String
    private let session: URLSession
    private var current: AccessToken?
    private var refreshing: Task<AccessToken, any Error>?

    public init(client: OAuthClient, refreshToken: String, current: AccessToken? = nil, session: URLSession = .shared) {
        self.client = client
        self.refreshToken = refreshToken
        self.current = current
        self.session = session
    }

    /// A token valid for at least another minute.
    public func token() async throws -> String {
        if let current, current.expiry.timeIntervalSinceNow > 60 { return current.value }
        return try await refresh().value
    }

    /// Forces a refresh, e.g. after Drive answered 401 with a token we thought was fine.
    public func invalidate() {
        current = nil
    }

    private func refresh() async throws -> AccessToken {
        // Reentrancy: a second caller arriving mid-refresh waits for the same task.
        if let refreshing { return try await refreshing.value }
        let task = Task { try await Self.requestToken(client: client, refreshToken: refreshToken, session: session) }
        refreshing = task
        defer { refreshing = nil }
        let token = try await task.value
        current = token
        return token
    }

    private static func requestToken(client: OAuthClient, refreshToken: String, session: URLSession) async throws -> AccessToken {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "client_id", value: client.id),
            URLQueryItem(name: "client_secret", value: client.secret),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "grant_type", value: "refresh_token"),
        ]
        request.httpBody = Data((form.percentEncodedQuery ?? "").utf8)

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        // 400 invalid_grant: the refresh token was revoked or expired. Only a new sign-in fixes that.
        if status == 400 || status == 401 { throw DriveError.signedOut }
        guard status == 200 else {
            throw DriveError.http(status: status, message: String(decoding: data, as: UTF8.self))
        }
        struct Reply: Decodable { let access_token: String; let expires_in: Int }
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        return AccessToken(value: reply.access_token, expiry: .now.addingTimeInterval(TimeInterval(reply.expires_in)))
    }
}
