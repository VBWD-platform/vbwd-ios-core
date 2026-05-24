/// Registry error for duplicate contributions (path/name/store id).
public enum RegistryError: Error, Equatable {
    case duplicateRoutePath(String)
    case duplicateRouteName(String)
    case duplicateStoreId(String)
}

/// Collects plugin-contributed routes. Port of the web SDK route list
/// (`addRoute`/`getRoutes`). Single responsibility: route storage only.
public final class RouteRegistry {
    private var routes: [PluginRoute] = []

    public init() {}

    public func add(_ route: PluginRoute) throws {
        if routes.contains(where: { $0.path == route.path }) {
            throw RegistryError.duplicateRoutePath(route.path)
        }
        if routes.contains(where: { $0.name == route.name }) {
            throw RegistryError.duplicateRouteName(route.name)
        }
        routes.append(route)
    }

    public func all() -> [PluginRoute] { routes }
}
