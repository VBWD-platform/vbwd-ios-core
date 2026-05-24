/// Where the app should be for a given auth state. Extracted from `RootView`
/// so the auth-guard decision (port of the web router guard) is unit-testable
/// without rendering SwiftUI (SRP).
public enum RootRoute: Equatable {
    case login
    case loading
    case dashboard(AuthUser)
}

public enum RootRouter {
    /// `.signedOut` / `.error` → login (web: unauthenticated → /login;
    /// error keeps the user on login with a banner). `.authenticating` →
    /// loading. `.authenticated` → dashboard.
    public static func route(for state: AuthState) -> RootRoute {
        switch state {
        case .signedOut, .error:        return .login
        case .authenticating:           return .loading
        case let .authenticated(user):  return .dashboard(user)
        }
    }
}
