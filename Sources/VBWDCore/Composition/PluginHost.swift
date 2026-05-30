import Foundation

/// Plugin composition root. Port of `vbwd-fe-user/vue/src/factory.ts`:
/// load manifest → register all compiled-in plugins → install the enabled ones
/// in dependency order → collect routes → activate. The **only** place the
/// compiled-in plugin list and the registry/SDK are constructed (DI). A
/// structural or per-plugin failure never blocks the shell (error isolation).
@MainActor
public final class PluginHost: ObservableObject {
    public let sdk: DefaultPlatformSDK
    private let registry = PluginRegistry()
    private let manifestLoader: PluginManifestLoader
    private let plugins: [Plugin]

    public private(set) var routes: [PluginRoute] = []
    public private(set) var manifest: PluginManifest = .empty
    /// Current navigation path driven by menu item taps.
    @Published public var selectedRoute: String? = nil

    public init(api: APIClient,
                apiConfig: APIClientConfig = APIClientConfig(baseURL: SDKContainer.defaultBaseURL),
                manifestLoader: PluginManifestLoader,
                plugins: [Plugin],
                cart: Cart = Cart(),
                checkoutSources: CheckoutSourceRegistry = CheckoutSourceRegistry(),
                events: EventBus? = nil) {
        // Reuse the host-provided bus when given (so AuthSession + plugins
        // share one channel — `AppEvents.authLogin` reaches subscribers);
        // fall back to a fresh bus for legacy callers + tests.
        let bus = events ?? DefaultEventBus(api: api)
        self.sdk = DefaultPlatformSDK(api: api, apiConfig: apiConfig,
                                      events: bus,
                                      cart: cart, checkoutSources: checkoutSources)
        self.manifestLoader = manifestLoader
        self.plugins = plugins
    }

    /// The dashboard reads this to surface enabled plugins' `Dashboard*` widgets.
    public var components: ComponentRegistry { sdk.components }

    public func bootstrap() async {
        manifest = await manifestLoader.load()
        for p in plugins { try? registry.register(p) }

        let enabled = manifest.enabledNames
        // Structural dep errors are isolated so the shell still loads with the
        // core + whatever installed (web-faithful resilience).
        do {
            try await registry.installAll(sdk, enabled: enabled)
        } catch {
            sdk.events.emit(AppEvents.pluginError, "\(error)")
        }

        routes = sdk.getRoutes()

        for p in plugins where enabled.contains(p.metadata.name) {
            if registry.status(of: p.metadata.name) == .installed {
                try? await registry.activate(p.metadata.name)
            }
        }
    }

    public func status(of name: String) -> PluginStatus? {
        registry.status(of: name)
    }
}
