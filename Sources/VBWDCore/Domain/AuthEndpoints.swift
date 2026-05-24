/// Auth endpoint paths. Defaults match the web `auth.ts` configuration, except
/// `profile`: the live backend has **no `/auth/me`** (404); the real profile
/// route is `/user/profile` with a different `{details,user}` shape, so
/// Sprint-01 sources the dashboard user from the login response (web parity:
/// the login response already includes `user`). A `/user/profile` refresh
/// adapter is deferred to Sprint 02. All paths are overridable (OCP).
public struct AuthEndpoints: Equatable, Sendable {
    public var login: String
    public var logout: String
    public var refresh: String
    public var profile: String

    public init(login: String = "/auth/login",
                logout: String = "/auth/logout",
                refresh: String = "/auth/refresh",
                profile: String = "/user/profile") {
        self.login = login
        self.logout = logout
        self.refresh = refresh
        self.profile = profile
    }
}
