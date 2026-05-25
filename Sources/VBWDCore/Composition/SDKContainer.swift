import Foundation

/// Composition root — the **only** place concrete adapters are named
/// (`URLSessionAPIClient`, `KeychainTokenStore`). Everything else depends on
/// protocols and is constructor-injected (DIP / DI compliance).
@MainActor
public final class SDKContainer {
    /// Fallback when no `vbwd_config.json` is bundled.
    nonisolated public static let defaultBaseURL = URL(string: "http://localhost:5000/api/v1")!

    public let config: APIClientConfig
    private let tokenProvider: AuthTokenProvider
    private let apiClient: APIClient
    private let tokenStore: TokenStore
    public let session: AuthSession
    public let themeRegistry: ThemeRegistry
    public let themeManager: ThemeManager
    public let cart: Cart
    public let checkoutSources: CheckoutSourceRegistry

    /// - Parameters:
    ///   - baseURL: API base; defaults to `vbwd_config.json` → `defaultBaseURL`.
    ///   - tokenStore: injectable; defaults to Keychain on device, but tests/
    ///     previews can pass `InMemoryTokenStore()`.
    public init(baseURL: URL? = nil,
                tokenStore: TokenStore? = nil) {
        let resolvedURL = baseURL
            ?? VBWDConfig.load()?.baseURL
            ?? SDKContainer.defaultBaseURL
        self.config = APIClientConfig(baseURL: resolvedURL)
        let provider = MutableTokenProvider()
        self.tokenProvider = provider
        self.apiClient = URLSessionAPIClient(config: config, tokenProvider: provider)
        self.tokenStore = tokenStore ?? KeychainTokenStore()
        let service = DefaultAuthService(client: apiClient, store: self.tokenStore)
        self.session = AuthSession(service: service)
        self.themeRegistry = ThemeRegistry()
        self.themeManager = ThemeManager(registry: themeRegistry)
        self.cart = Cart()
        self.checkoutSources = CheckoutSourceRegistry()

        // Register the built-in token bundle checkout source.
        let bundleSource = TokenBundleCheckoutSource(api: apiClient, cart: cart)
        checkoutSources.register(bundleSource)

        // Auto sign-out on 401 (expired / invalid token). The web client does
        // the same via its axios response interceptor → `clearToken()`.
        let session = self.session
        apiClient.on(.tokenExpired) { [weak session] in
            Task { @MainActor in
                guard let session, session.isAuthenticated else { return }
                await session.signOut()
            }
        }
    }

    public func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(session: session)
    }

    public func makeDashboardViewModel(user: AuthUser,
                                       components: ComponentRegistry? = nil) -> DashboardViewModel {
        DashboardViewModel(user: user, api: apiClient, components: components)
    }

    public func makeProfileViewModel() -> ProfileViewModel {
        let service = DefaultProfileService(client: apiClient)
        return ProfileViewModel(service: service)
    }

    func makeTokensViewModel() -> TokensViewModel {
        TokensViewModel(api: apiClient)
    }

    func makeBuyTokensViewModel() -> BuyTokensViewModel {
        BuyTokensViewModel(api: apiClient)
    }

    func makeInvoicesViewModel() -> InvoicesViewModel {
        InvoicesViewModel(api: apiClient)
    }

    func makeInvoiceDetailViewModel(invoiceId: String) -> InvoiceDetailViewModel {
        InvoiceDetailViewModel(api: apiClient, invoiceId: invoiceId)
    }

    func makeCheckoutViewModel(context: CheckoutContext,
                               components: ComponentRegistry? = nil,
                               events: EventBus? = nil) -> CheckoutViewModel {
        CheckoutViewModel(api: apiClient,
                          context: context,
                          cart: cart,
                          checkoutSources: checkoutSources,
                          components: components,
                          events: events)
    }

    /// Builds the plugin composition root. `manifestLoader` defaults to the
    /// remote loader (backend single writer, configurable path) with a bundled
    /// fallback; pass `InMemoryPluginManifestLoader` for tests/previews.
    public func makePluginHost(plugins: [Plugin],
                               manifestLoader: PluginManifestLoader? = nil,
                               manifestPath: String = "/admin/frontend-plugins/user",
                               fallback: PluginManifest = .empty) -> PluginHost {
        let loader = manifestLoader ?? RemotePluginManifestLoader(
            api: apiClient, path: manifestPath, fallback: fallback)
        return PluginHost(api: apiClient, manifestLoader: loader, plugins: plugins,
                          cart: cart, checkoutSources: checkoutSources)
    }
}
