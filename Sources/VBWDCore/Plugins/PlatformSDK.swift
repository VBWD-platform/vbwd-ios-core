import SwiftUI

/// A screen contributed by a plugin. Port of the web `IRouteConfig`
/// (path/name/lazy component + auth & permission meta).
public struct PluginRoute {
    public let path: String
    public let name: String
    public let requiresAuth: Bool
    public let requiredUserPermission: String?
    /// When `true`, any route starting with `path` will match (e.g. path
    /// `/meinchat` matches `/meinchat/nickname`). Default is `false` (exact).
    public let matchPrefix: Bool
    public let view: @MainActor () -> AnyView

    public init(path: String, name: String,
                requiresAuth: Bool = false,
                requiredUserPermission: String? = nil,
                matchPrefix: Bool = false,
                view: @MainActor @escaping () -> AnyView) {
        self.path = path
        self.name = name
        self.requiresAuth = requiresAuth
        self.requiredUserPermission = requiredUserPermission
        self.matchPrefix = matchPrefix
        self.view = view
    }
}

/// Facade handed to a plugin's `install(_:)`. Port of the web `IPlatformSDK`
/// (types.ts:205-265). A plugin depends on **this protocol only** — never on
/// the registries, registry, or composition root (ISP/DIP).
public protocol PlatformSDK: AnyObject, Sendable {
    var api: APIClient { get }
    var events: EventBus { get }

    func addRoute(_ route: PluginRoute) throws
    func getRoutes() -> [PluginRoute]

    func addComponent(_ name: String, _ factory: @escaping ComponentFactory)
    func removeComponent(_ name: String)
    func getComponents() -> [String: ComponentFactory]

    func createStore(_ id: String, _ store: AnyObject) throws
    func getStores() -> [String: AnyObject]

    func addTranslations(_ locale: String, _ messages: [String: String])
    func getTranslations() -> [String: [String: String]]
    
    // Sprint 03 - Menu item injection
    func addMenuItem(_ item: MenuItem)
    func removeMenuItem(_ id: String)
    func getMenuItems() -> [MenuItem]

    // Payment action handlers (post-checkout routing)
    func addPaymentAction(_ code: String, _ handler: @escaping PaymentActionHandler)

    // Sprint 06c — Cart + Checkout Source
    var cart: Cart { get }
    var checkoutSources: CheckoutSourceRegistry { get }
    @MainActor func addCheckoutSource(_ source: CheckoutSource)
    @MainActor func removeCheckoutSource(id: String)
}

/// Thin facade over the four registries + injected `api`/`events`. Port of
/// `PlatformSDK.ts` — forwards only, no behaviour of its own (DRY/SRP).
/// Registries are exposed for the composition root / app shell to consume;
/// plugins still see only the `PlatformSDK` protocol.
public final class DefaultPlatformSDK: PlatformSDK, @unchecked Sendable {
    public let api: APIClient
    public let events: EventBus
    public let routes: RouteRegistry
    public let components: ComponentRegistry
    public let stores: StoreRegistry
    public let localizations: LocalizationRegistry
    public let menuItems: MenuItemRegistry  // Sprint 03
    public let cart: Cart                   // Sprint 06c
    public let checkoutSources: CheckoutSourceRegistry  // Sprint 06c

    public init(api: APIClient,
                events: EventBus,
                routes: RouteRegistry = RouteRegistry(),
                components: ComponentRegistry = ComponentRegistry(),
                stores: StoreRegistry = StoreRegistry(),
                localizations: LocalizationRegistry = LocalizationRegistry(),
                menuItems: MenuItemRegistry = MenuItemRegistry(),
                cart: Cart,
                checkoutSources: CheckoutSourceRegistry) {
        self.api = api
        self.events = events
        self.routes = routes
        self.components = components
        self.stores = stores
        self.localizations = localizations
        self.menuItems = menuItems
        self.cart = cart
        self.checkoutSources = checkoutSources
    }

    public func addRoute(_ route: PluginRoute) throws { try routes.add(route) }
    public func getRoutes() -> [PluginRoute] { routes.all() }

    public func addComponent(_ name: String, _ factory: @escaping ComponentFactory) {
        components.add(name, factory)
    }
    public func removeComponent(_ name: String) { components.remove(name) }
    public func getComponents() -> [String: ComponentFactory] { components.all() }

    public func createStore(_ id: String, _ store: AnyObject) throws {
        try stores.create(id, store)
    }
    public func getStores() -> [String: AnyObject] { stores.all() }

    public func addTranslations(_ locale: String, _ messages: [String: String]) {
        localizations.add(locale, messages)
    }
    public func getTranslations() -> [String: [String: String]] {
        localizations.all()
    }
    
    // Sprint 03 - Menu item APIs
    public func addMenuItem(_ item: MenuItem) {
        menuItems.add(item)
    }
    
    public func removeMenuItem(_ id: String) {
        menuItems.remove(id)
    }
    
    public func getMenuItems() -> [MenuItem] {
        menuItems.all()
    }

    public func addPaymentAction(_ code: String, _ handler: @escaping PaymentActionHandler) {
        components.addPaymentAction(code, handler)
    }

    @MainActor public func addCheckoutSource(_ source: CheckoutSource) {
        checkoutSources.register(source)
    }

    @MainActor public func removeCheckoutSource(id: String) {
        checkoutSources.unregister(id: id)
    }
}
