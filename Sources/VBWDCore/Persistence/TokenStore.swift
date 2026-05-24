import Foundation

/// Token persistence contract. Mirrors the three web `localStorage` keys from
/// `auth.ts`: access token, refresh token, encoded user blob. Domain depends on
/// this protocol; the concrete store is injected (DIP).
public protocol TokenStore: AnyObject, Sendable {
    func saveToken(_ token: String) throws
    func loadToken() throws -> String?
    func saveRefreshToken(_ token: String) throws
    func loadRefreshToken() throws -> String?
    func saveUser(_ data: Data) throws
    func loadUser() throws -> Data?
    func clear() throws
}

/// In-memory store. Production-usable (previews/tests) and the substitutable
/// twin proving Liskov against the Keychain store via the shared contract.
public final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private var token: String?
    private var refreshToken: String?
    private var user: Data?

    public init() {}

    public func saveToken(_ token: String) throws { self.token = token }
    public func loadToken() throws -> String? { token }
    public func saveRefreshToken(_ token: String) throws { refreshToken = token }
    public func loadRefreshToken() throws -> String? { refreshToken }
    public func saveUser(_ data: Data) throws { user = data }
    public func loadUser() throws -> Data? { user }
    public func clear() throws {
        token = nil
        refreshToken = nil
        user = nil
    }
}
