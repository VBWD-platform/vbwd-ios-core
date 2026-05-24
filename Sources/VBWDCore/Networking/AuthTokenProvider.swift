/// Where the bearer token comes from. Segregated from the client (ISP): the
/// transport asks for a token, it does not own auth state. Mirrors the web
/// request interceptor reading the store's token.
public protocol AuthTokenProvider: AnyObject {
    var token: String? { get set }
}

/// Default mutable provider. `AuthService` writes it via `APIClient.setToken`.
public final class MutableTokenProvider: AuthTokenProvider {
    public var token: String?
    public init(token: String? = nil) { self.token = token }
}
