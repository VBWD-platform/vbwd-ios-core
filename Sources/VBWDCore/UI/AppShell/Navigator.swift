/// Pure route-resolution decision. Port of the `router/index.ts` guards
/// (auth + permission + 404-last). Extracted from the view so it is
/// unit-testable without rendering (SRP — mirrors Sprint 01 `RootRouter`).
public enum RouteResolution: Equatable {
    case allow
    case redirectToLogin
    case forbidden
    case notFound
}

public enum Navigator {
    /// First matching route by path wins, so callers placing core routes
    /// before plugin routes get core precedence (web router order). Unknown
    /// path → `.notFound` (the 404 catch-all is conceptually last).
    public static func resolve(path: String,
                               routes: [PluginRoute],
                               isAuthenticated: Bool,
                               userPermissions: [String],
                               evaluator: PermissionEvaluator = PermissionEvaluator())
        -> RouteResolution {
        guard let route = routes.first(where: { $0.path == path }) else {
            return .notFound
        }
        if route.requiresAuth && !isAuthenticated {
            return .redirectToLogin
        }
        if let needed = route.requiredUserPermission,
           !evaluator.has(needed, in: userPermissions) {
            return .forbidden
        }
        return .allow
    }
}
