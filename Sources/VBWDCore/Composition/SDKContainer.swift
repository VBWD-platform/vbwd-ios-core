import Foundation

/// Composition root — the **only** place concrete adapters are named
/// (`URLSessionAPIClient`, `KeychainTokenStore`). Everything else depends on
/// protocols and is constructor-injected (DIP / DI compliance).
@MainActor
public final class SDKContainer {
    /// Dev backend (same local Docker backend the web apps use).
    nonisolated public static let defaultBaseURL = URL(string: "https://vbwd.cc/api/v1")!

    public let config: APIClientConfig
    private let tokenProvider: AuthTokenProvider
    private let apiClient: APIClient
    private let tokenStore: TokenStore
    public let session: AuthSession
    public let themeRegistry: ThemeRegistry
    public let themeManager: ThemeManager

    /// - Parameters:
    ///   - baseURL: API base; defaults to the local backend, overridable for
    ///     prod / physical-device (LAN IP).
    ///   - tokenStore: injectable; defaults to Keychain on device, but tests/
    ///     previews can pass `InMemoryTokenStore()`.
    public init(baseURL: URL = SDKContainer.defaultBaseURL,
                tokenStore: TokenStore? = nil) {
        self.config = APIClientConfig(baseURL: baseURL)
        let provider = MutableTokenProvider()
        self.tokenProvider = provider
        self.apiClient = URLSessionAPIClient(config: config, tokenProvider: provider)
        self.tokenStore = tokenStore ?? KeychainTokenStore()
        let service = DefaultAuthService(client: apiClient, store: self.tokenStore)
        self.session = AuthSession(service: service)
        self.themeRegistry = ThemeRegistry()
        self.themeManager = ThemeManager(registry: themeRegistry)
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

    /// Builds the plugin composition root. `manifestLoader` defaults to the
    /// remote loader (backend single writer, configurable path) with a bundled
    /// fallback; pass `InMemoryPluginManifestLoader` for tests/previews.
    public func makePluginHost(plugins: [Plugin],
                               manifestLoader: PluginManifestLoader? = nil,
                               manifestPath: String = "/admin/frontend-plugins/user",
                               fallback: PluginManifest = .empty) -> PluginHost {
        let loader = manifestLoader ?? RemotePluginManifestLoader(
            api: apiClient, path: manifestPath, fallback: fallback)
        return PluginHost(api: apiClient, manifestLoader: loader, plugins: plugins)
    }
}
