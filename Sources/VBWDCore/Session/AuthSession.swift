import Foundation
import Combine

/// Observable auth state machine. Port of the `auth.ts` reactive store for the
/// SwiftUI layer. Depends only on `AuthService` (ISP/DIP) — knows nothing of
/// transport or persistence.
@MainActor
public final class AuthSession: ObservableObject {
    @Published public private(set) var state: AuthState = .signedOut

    private let service: AuthService

    public init(service: AuthService) {
        self.service = service
    }

    /// Web `isAuthenticated`: token && user (here: an authenticated state).
    public var isAuthenticated: Bool {
        if case .authenticated = state { return true }
        return false
    }

    public var currentUser: AuthUser? {
        if case let .authenticated(u) = state { return u }
        return nil
    }

    /// Web `initAuth`: restore persisted session on app start.
    public func start() {
        if let user = service.restore() {
            state = .authenticated(user)
        } else {
            state = .signedOut
        }
    }

    public func signIn(email: String, password: String) async {
        state = .authenticating
        do {
            let user = try await service.login(.init(email: email, password: password))
            state = .authenticated(user)
        } catch {
            let message = (error as? APIError)?.message ?? "Login failed"
            state = .error(message)
        }
    }

    public func signOut() async {
        await service.logout()
        state = .signedOut
    }
}
