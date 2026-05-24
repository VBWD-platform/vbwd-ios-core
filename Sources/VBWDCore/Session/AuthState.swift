/// Reactive auth state for the UI layer (replaces the web Pinia store shape).
public enum AuthState: Equatable {
    case signedOut
    case authenticating
    case authenticated(AuthUser)
    case error(String)
}
