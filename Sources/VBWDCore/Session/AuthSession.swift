import Foundation
import Combine

/// Observable auth state machine. Port of the `auth.ts` reactive store for the
/// SwiftUI layer. Depends only on `AuthService` (ISP/DIP) — knows nothing of
/// transport or persistence.
@MainActor
public final class AuthSession: ObservableObject {
    @Published public private(set) var state: AuthState = .signedOut

    private let service: AuthService
    /// Optional event bus — when injected, the session emits
    /// `AppEvents.authLogin` on successful login + restore so plugins
    /// (e.g. meinchat's limits service) can trigger their first auth-gated
    /// fetch without polling for state changes.
    private let events: EventBus?

    public init(service: AuthService, events: EventBus? = nil) {
        self.service = service
        self.events = events
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

    /// Current access token, if the session is authenticated. Plugins
    /// use this when they need to forward the JWT outside the normal
    /// `APIClient` request path — e.g. the S91 CMS plugin seeds it
    /// into a `WKWebView`'s `localStorage` so the embedded web app
    /// shares the user's session.
    public var accessToken: String? {
        service.currentToken()
    }

    /// Web `initAuth`: restore persisted session on app start.
    public func start() {
        if let user = service.restore() {
            state = .authenticated(user)
            events?.emit(AppEvents.authLogin, nil)
        } else {
            state = .signedOut
        }
    }

    public func signIn(email: String, password: String) async {
        state = .authenticating
        do {
            let user = try await service.login(.init(email: email, password: password))
            state = .authenticated(user)
            events?.emit(AppEvents.authLogin, nil)
        } catch {
            let message = (error as? APIError)?.message ?? "Login failed"
            state = .error(message)
        }
    }

    public func signOut() async {
        // Emit before the token is cleared so listeners doing best-effort
        // authenticated calls (e.g. meinchat's device-token unregister,
        // S67.2) still have a chance to carry the JWT.
        events?.emit(AppEvents.authLogout, nil)
        await service.logout()
        state = .signedOut
    }
}
