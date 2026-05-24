import Foundation

/// Auth orchestration contract. Port of the `auth.ts` actions. Session/UI
/// depend on this protocol, never on the concrete service (DIP).
public protocol AuthService: AnyObject, Sendable {
    /// POST login; on success persists token/refresh/user and returns the user.
    func login(_ credentials: Credentials) async throws -> AuthUser
    /// Calls logout (errors ignored, web parity) then clears local state.
    func logout() async
    /// Restores persisted session (web `initAuth`). Returns the user if a token
    /// is present and the user blob decodes, else nil.
    func restore() -> AuthUser?
    /// Fetches the profile from the configured endpoint.
    func fetchProfile() async throws -> AuthUser
    /// Deferred to Sprint 02 — throws `.notImplemented`.
    func refreshAccessToken() async throws -> String
}

/// Default `AuthService`. Depends only on injected protocols (DIP); holds no
/// UI/transport concretions (SRP).
public final class DefaultAuthService: AuthService, @unchecked Sendable {
    private let client: APIClient
    private let store: TokenStore
    private let endpoints: AuthEndpoints
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(client: APIClient,
                store: TokenStore,
                endpoints: AuthEndpoints = AuthEndpoints()) {
        self.client = client
        self.store = store
        self.endpoints = endpoints
    }

    public func login(_ credentials: Credentials) async throws -> AuthUser {
        // Invalid credentials → backend 401 → APIClient throws here; nothing
        // is persisted because persistence happens only after this returns.
        let response: LoginResponse = try await client.post(
            endpoints.login, body: credentials)

        guard let token = response.token, !token.isEmpty,
              response.success != false,
              let user = response.user else {
            throw APIError.http(status: 401,
                                message: response.error ?? "Login failed")
        }

        try store.saveToken(token)
        if let refresh = response.refreshToken {
            try store.saveRefreshToken(refresh)
        }
        if let blob = try? encoder.encode(user) {
            try store.saveUser(blob)
        }
        client.setToken(token)
        return user
    }

    public func logout() async {
        // Best-effort server logout; ignore its outcome (web `.catch(()=>{})`).
        let _: EmptyResponse? = try? await client.post(endpoints.logout)
        try? store.clear()
        client.setToken(nil)
    }

    public func restore() -> AuthUser? {
        guard let token = try? store.loadToken(), !token.isEmpty else {
            return nil
        }
        client.setToken(token)
        guard let blob = try? store.loadUser() else { return nil }
        return try? decoder.decode(AuthUser.self, from: blob)
    }

    public func fetchProfile() async throws -> AuthUser {
        try await client.get(endpoints.profile)
    }

    public func refreshAccessToken() async throws -> String {
        throw APIError.notImplemented("token refresh deferred to Sprint 02")
    }
}
