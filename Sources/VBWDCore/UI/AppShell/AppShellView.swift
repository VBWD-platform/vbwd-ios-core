import SwiftUI

/// Thin navigation host. All routing decisions are delegated to `Navigator`
/// (no logic in `body`). Renders the resolved plugin route, or the login /
/// forbidden / not-found fallbacks. Full wiring (routes + auth from the
/// `PluginHost`) is completed in Subsprint 2.7.
public struct AppShellView<Login: View, Forbidden: View, NotFound: View>: View {
    private let path: String
    private let routes: [PluginRoute]
    private let isAuthenticated: Bool
    private let userPermissions: [String]
    private let login: () -> Login
    private let forbidden: () -> Forbidden
    private let notFound: () -> NotFound

    public init(path: String,
                routes: [PluginRoute],
                isAuthenticated: Bool,
                userPermissions: [String],
                @ViewBuilder login: @escaping () -> Login,
                @ViewBuilder forbidden: @escaping () -> Forbidden,
                @ViewBuilder notFound: @escaping () -> NotFound) {
        self.path = path
        self.routes = routes
        self.isAuthenticated = isAuthenticated
        self.userPermissions = userPermissions
        self.login = login
        self.forbidden = forbidden
        self.notFound = notFound
    }

    public var body: some View {
        switch Navigator.resolve(path: path, routes: routes,
                                 isAuthenticated: isAuthenticated,
                                 userPermissions: userPermissions) {
        case .allow:
            if let r = routes.first(where: { $0.path == path }) { r.view() }
        case .redirectToLogin:
            login()
        case .forbidden:
            forbidden()
        case .notFound:
            notFound()
        }
    }
}
