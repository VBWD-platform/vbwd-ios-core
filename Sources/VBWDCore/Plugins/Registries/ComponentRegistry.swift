import SwiftUI

/// Lazy view factory a plugin registers (web `ComponentDefinition`).
public typealias ComponentFactory = () -> AnyView

/// Named component registry. Port of `addComponent`/`removeComponent`/
/// `getComponents`. Owns the single `Dashboard*` filter the dashboard reuses
/// (DRY — web `Dashboard.vue` `name.startsWith('Dashboard')`).
public final class ComponentRegistry {
    private var components: [String: ComponentFactory] = [:]
    private var order: [String] = []

    public init() {}

    public func add(_ name: String, _ factory: @escaping ComponentFactory) {
        if components[name] == nil { order.append(name) }
        components[name] = factory
    }

    public func remove(_ name: String) {
        components[name] = nil
        order.removeAll { $0 == name }
    }

    public func get(_ name: String) -> ComponentFactory? { components[name] }

    public func all() -> [String: ComponentFactory] { components }

    /// Names in registration order (deterministic widget ordering).
    public func names() -> [String] { order }

    /// The web dashboard-widget convention: components named `Dashboard*`,
    /// in registration order.
    public func dashboardComponents() -> [(name: String, factory: ComponentFactory)] {
        order.filter { $0.hasPrefix("Dashboard") }
             .compactMap { n in components[n].map { (n, $0) } }
    }

    /// Profile extension convention: components named `Profile*`,
    /// in registration order. Plugins register these to add sections to the
    /// profile screen (mirrors the `Dashboard*` pattern).
    public func profileComponents() -> [(name: String, factory: ComponentFactory)] {
        order.filter { $0.hasPrefix("Profile") }
             .compactMap { n in components[n].map { (n, $0) } }
    }

    /// Checkout extension convention: components named `Checkout*`,
    /// in registration order. Plugins register these to inject sections into
    /// the checkout screen (e.g. discount codes, shipping, insurance).
    public func checkoutComponents() -> [(name: String, factory: ComponentFactory)] {
        order.filter { $0.hasPrefix("Checkout") }
             .compactMap { n in components[n].map { (n, $0) } }
    }
}
