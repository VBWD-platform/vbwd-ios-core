import Foundation
import VBWDCore

/// Scriptable `AuthService` double for Session/UI tests.
final class SpyAuthService: AuthService, @unchecked Sendable {
    var loginResult: Result<AuthUser, Error> =
        .failure(APIError.http(status: 401, message: "Invalid credentials"))
    var restoreUser: AuthUser?
    private(set) var loginCalls = 0
    private(set) var logoutCalled = false

    func login(_ credentials: Credentials) async throws -> AuthUser {
        loginCalls += 1
        return try loginResult.get()
    }
    func logout() async { logoutCalled = true }
    func restore() -> AuthUser? { restoreUser }
    func fetchProfile() async throws -> AuthUser { try loginResult.get() }
    func refreshAccessToken() async throws -> String {
        throw APIError.notImplemented("deferred")
    }
}

enum Fixtures {
    static func user(name: String = "Jane Doe",
                     permissions: [String] = []) -> AuthUser {
        AuthUser(id: "1", email: "jane@example.com", name: name,
                 userPermissions: permissions)
    }
}
