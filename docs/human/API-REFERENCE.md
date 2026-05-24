# VBWDCore API Reference

Complete reference for all public types, protocols, and methods in the VBWDCore module.

---

## Table of Contents

1. [Networking](#networking)
2. [Persistence](#persistence)
3. [Domain](#domain)
4. [Session](#session)
5. [Events](#events)
6. [Plugin System](#plugin-system)
7. [Registries](#registries)
8. [Themes](#themes)
9. [Composition](#composition)
10. [UI](#ui)

---

## Networking

### `APIClient` (protocol)

The core HTTP client interface. All domain code depends on this protocol.

```swift
protocol APIClient: AnyObject, Sendable {
    func get<R: Decodable>(_ path: String) async throws -> R
    func post<R: Decodable>(_ path: String, body: (any Encodable)?) async throws -> R
    func put<R: Decodable>(_ path: String, body: (any Encodable)?) async throws -> R
    func patch<R: Decodable>(_ path: String, body: (any Encodable)?) async throws -> R
    func delete<R: Decodable>(_ path: String) async throws -> R
    func setToken(_ token: String?)
    func on(_ event: APIEvent, _ handler: @escaping @Sendable () -> Void)
}
```

Default convenience overloads:
- `post(_ path: String)` — POST with no body
- `put(_ path: String)` — PUT with no body

### `APIClientConfig`

```swift
struct APIClientConfig: Equatable, Sendable {
    static let defaultTimeout: TimeInterval  // 30 seconds
    let baseURL: URL
    let timeout: TimeInterval
    let headers: [String: String]
    init(baseURL: URL, timeout: TimeInterval = defaultTimeout, headers: [String: String] = [:])
}
```

`Content-Type: application/json` is always injected. Caller headers override defaults.

### `APIError`

```swift
enum APIError: Error, Equatable {
    case http(status: Int, message: String)
    case transport(message: String)
    case decoding(message: String)
    case notImplemented(String)

    var message: String { get }
    static func fromResponse(status: Int, body: Data, statusText: String) -> APIError
    static func fromTransport(_ error: Error) -> APIError
    static func fromDecoding(_ error: Error) -> APIError
}
```

### `APIEvent`

```swift
enum APIEvent: Hashable, Sendable {
    case tokenExpired
}
```

### `URLSessionAPIClient`

Production implementation. Automatically adds `Authorization: Bearer <token>` header. Fires `.tokenExpired` on HTTP 401.

```swift
final class URLSessionAPIClient: APIClient, @unchecked Sendable {
    init(config: APIClientConfig,
         session: URLSession = .shared,
         tokenProvider: AuthTokenProvider = MutableTokenProvider())
}
```

### `AuthTokenProvider` (protocol)

```swift
protocol AuthTokenProvider: AnyObject {
    var token: String? { get set }
}
```

### `MutableTokenProvider`

```swift
final class MutableTokenProvider: AuthTokenProvider {
    var token: String?
    init(token: String? = nil)
}
```

### `EmptyResponse`

Decode target for endpoints that return no meaningful body (e.g., logout).

```swift
struct EmptyResponse: Codable, Equatable, Sendable {
    init()
}
```

### `HTTPMethod`

```swift
enum HTTPMethod: String, Equatable, Sendable {
    case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
}
```

---

## Persistence

### `TokenStore` (protocol)

```swift
protocol TokenStore: AnyObject, Sendable {
    func saveToken(_ token: String) throws
    func loadToken() throws -> String?
    func saveRefreshToken(_ token: String) throws
    func loadRefreshToken() throws -> String?
    func saveUser(_ data: Data) throws
    func loadUser() throws -> Data?
    func clear() throws
}
```

### `KeychainTokenStore`

Production implementation using the iOS Keychain.

```swift
final class KeychainTokenStore: TokenStore, @unchecked Sendable {
    init(service: String = "com.vbwd.sdk.auth")
}
```

### `InMemoryTokenStore`

In-memory implementation for tests and previews.

```swift
final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    init()
}
```

---

## Domain

### `AuthService` (protocol)

```swift
protocol AuthService: AnyObject, Sendable {
    func login(_ credentials: Credentials) async throws -> AuthUser
    func logout() async
    func restore() -> AuthUser?
    func fetchProfile() async throws -> AuthUser
    func refreshAccessToken() async throws -> String
}
```

### `DefaultAuthService`

```swift
final class DefaultAuthService: AuthService, @unchecked Sendable {
    init(client: APIClient, store: TokenStore, endpoints: AuthEndpoints = AuthEndpoints())
}
```

### `ProfileService` (protocol)

```swift
protocol ProfileService: AnyObject, Sendable {
    func fetchProfile() async throws -> UserProfile
    func updateDetails(_ profile: UserProfile) async throws -> UserProfile
    func changePassword(current: String, new: String) async throws
}
```

### `DefaultProfileService`

```swift
final class DefaultProfileService: ProfileService, @unchecked Sendable {
    init(client: APIClient, endpoints: ProfileEndpoints = ProfileEndpoints())
}
```

### `AuthUser`

```swift
struct AuthUser: Codable, Equatable, Sendable {
    let id: String
    let email: String
    let name: String?
    let role: String?
    let isAdmin: Bool?
    let accessLevels: [AccessLevel]?
    let permissions: [String]?
    let userAccessLevels: [AccessLevel]?
    let userPermissions: [String]?
}
```

### `AccessLevel`

```swift
struct AccessLevel: Codable, Equatable, Sendable {
    let id: String, slug: String, name: String
}
```

### `Credentials`

```swift
struct Credentials: Codable, Equatable, Sendable {
    let email: String, password: String
}
```

### `UserProfile`

```swift
struct UserProfile: Codable, Equatable, Sendable {
    var firstName: String
    var lastName: String
    var company: String
    var taxNumber: String
    var phone: String
    var addressLine1: String
    var addressLine2: String
    var city: String
    var postalCode: String
    var country: String    // ISO 3166-1 alpha-2
}
```

Custom decoder treats `null` JSON values as empty strings.

### `LoginResponse`

```swift
struct LoginResponse: Codable, Equatable, Sendable {
    let success: Bool?
    let token: String?
    let refreshToken: String?
    let user: AuthUser?
    let userId: String?
    let error: String?
}
```

### `PermissionEvaluator`

```swift
struct PermissionEvaluator: Sendable {
    func has(_ permission: String, in granted: [String]) -> Bool
    func hasAny(_ permissions: [String], in granted: [String]) -> Bool
}
```

Supports `*` (full wildcard) and `"prefix.*"` (namespace wildcard) patterns.

### Configurable Endpoints

```swift
struct AuthEndpoints: Equatable, Sendable {
    var login: String       // default: "/auth/login"
    var logout: String      // default: "/auth/logout"
    var refresh: String     // default: "/auth/refresh"
    var profile: String     // default: "/user/profile"
}

struct ProfileEndpoints: Equatable, Sendable {
    var profile: String         // default: "/user/profile"
    var updateDetails: String   // default: "/user/details"
    var changePassword: String  // default: "/user/change-password"
}

struct DashboardEndpoints: Equatable, Sendable {
    var tokenBalance: String       // default: "/user/tokens/balance"
    var tokenTransactions: String  // default: "/user/tokens/transactions?limit=10"
    var invoices: String           // default: "/invoices/"
}
```

### Dashboard Models

```swift
struct Invoice: Codable, Equatable, Sendable, Identifiable {
    let id: String, invoiceNumber: String?, invoicedAt: String?, amount: String?, status: String?
}

struct TokenTransaction: Codable, Equatable, Sendable, Identifiable {
    let id: String, amount: Double, transactionType: String?, createdAt: String?
}
```

---

## Session

### `AuthState`

```swift
enum AuthState: Equatable {
    case signedOut
    case authenticating
    case authenticated(AuthUser)
    case error(String)
}
```

### `AuthSession`

```swift
@MainActor final class AuthSession: ObservableObject {
    @Published private(set) var state: AuthState
    var isAuthenticated: Bool { get }
    var currentUser: AuthUser? { get }

    init(service: AuthService)
    func start()                                    // restore persisted session
    func signIn(email: String, password: String) async
    func signOut() async
}
```

---

## Events

### `EventBus` (protocol)

```swift
protocol EventBus: AnyObject, Sendable {
    func emit(_ name: String, _ payload: (any Sendable)?)
    func emit(_ name: String)
    @discardableResult func on(_ name: String, _ callback: @escaping @Sendable (any Sendable) -> Void) -> Unsubscribe
    func once(_ name: String, _ callback: @escaping @Sendable (any Sendable) -> Void)
    func off(_ name: String)
    func hasListeners(_ name: String) async -> Bool
    func listenerCount(_ name: String) async -> Int
    func history(_ name: String?) async -> [EventRecord]
    func clear()
    func clearHistory()
    @discardableResult func sendToBackend(_ name: String, _ payload: (any Encodable & Sendable)?) async -> Bool
    func flushPending() async -> Bool
    func pendingCount() async -> Int
}
```

### `DefaultEventBus`

```swift
final class DefaultEventBus: EventBus {
    init(api: APIClient, endpoint: String = "/events", maxHistory: Int = 100,
         localOnly: Set<String> = AppEvents.localOnly)
}
```

### `Unsubscribe`

```swift
typealias Unsubscribe = @Sendable () -> Void
```

### `EventRecord`

```swift
struct EventRecord: Equatable, Sendable {
    let name: String, at: Date
}
```

### `AppEvents` — Event Name Constants

**Auth**: `authLogin`, `authLogout`, `authTokenRefreshed`, `authSessionExpired`

**User**: `userRegistered`, `userUpdated`, `userDeleted`

**Subscription**: `subscriptionCreated`, `subscriptionActivated`, `subscriptionUpgraded`, `subscriptionDowngraded`, `subscriptionCancelled`, `subscriptionExpired`

**Payment**: `paymentInitiated`, `paymentSucceeded`, `paymentFailed`, `paymentRefunded`

**Plugin**: `pluginRegistered`, `pluginInitialized`, `pluginError`, `pluginStopped`

**UI-local** (not forwarded to backend): `notificationShow`, `notificationHide`, `modalOpen`, `modalClose`, `loadingStart`, `loadingEnd`

**WebSocket**: `wsConnected`, `wsDisconnected`, `wsMessage`, `wsError`

---

## Plugin System

### `Plugin` (protocol)

```swift
protocol Plugin: AnyObject, Sendable {
    var metadata: PluginMetadata { get }
    func install(_ sdk: PlatformSDK) async throws
    func activate() async throws       // default: no-op
    func deactivate() async throws     // default: no-op
    func uninstall() async throws      // default: no-op
}
```

### `PluginMetadata`

```swift
struct PluginMetadata: Equatable, Sendable {
    let name: String                           // unique, kebab-case
    let version: SemanticVersion
    let description: String?
    let author: String?
    let homepage: String?
    let keywords: [String]
    let dependencies: PluginDependencies
    let translations: [String: [String: String]]  // locale → key → value
}
```

### `PluginDependencies`

```swift
enum PluginDependencies: Equatable, Sendable {
    case none
    case list([String])                          // any version
    case constrained([String: String])           // name → semver constraint
}
```

### `PluginStatus`

```swift
enum PluginStatus: Equatable, Sendable {
    case registered, installed, active, inactive, error(String)
}
```

### `PluginError`

```swift
enum PluginError: Error, Equatable {
    case invalidVersion(String)
    case duplicate(String)
    case missingDependency(plugin: String, dependency: String)
    case unsatisfiedVersion(plugin: String, dependency: String, constraint: String)
    case circularDependency([String])
    case invalidState(plugin: String, message: String)
    case installFailed(plugin: String, message: String)
}
```

### `SemanticVersion`

```swift
struct SemanticVersion: Comparable, Equatable, CustomStringConvertible, Sendable {
    let major: Int, minor: Int, patch: Int
    init(_ major: Int, _ minor: Int, _ patch: Int)
    init(parsing string: String) throws          // "1.2.3" format
}
```

### `VersionConstraint`

```swift
struct VersionConstraint: Equatable, Sendable {
    init(_ raw: String)
    func isSatisfied(by version: SemanticVersion) -> Bool
}
```

Supports: `^1.2.3` (caret), `~1.2.3` (tilde), `>=`, `>`, `<=`, `<`, `1.x.x` (x-ranges), `*`, exact match.

### `PlatformSDK` (protocol)

The facade passed to `plugin.install()`.

```swift
protocol PlatformSDK: AnyObject, Sendable {
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
    func addMenuItem(_ item: MenuItem)
    func removeMenuItem(_ id: String)
    func getMenuItems() -> [MenuItem]
}
```

### `DefaultPlatformSDK`

```swift
final class DefaultPlatformSDK: PlatformSDK, @unchecked Sendable {
    let api: APIClient
    let events: EventBus
    let routes: RouteRegistry
    let components: ComponentRegistry
    let stores: StoreRegistry
    let localizations: LocalizationRegistry
    let menuItems: MenuItemRegistry

    init(api: APIClient, events: EventBus,
         routes: RouteRegistry = RouteRegistry(),
         components: ComponentRegistry = ComponentRegistry(),
         stores: StoreRegistry = StoreRegistry(),
         localizations: LocalizationRegistry = LocalizationRegistry(),
         menuItems: MenuItemRegistry = MenuItemRegistry())
}
```

### `PluginRoute`

```swift
struct PluginRoute {
    let path: String                     // must be unique, start with /
    let name: String                     // must be unique
    let requiresAuth: Bool               // default: false
    let requiredUserPermission: String?  // default: nil
    let view: () -> AnyView
}
```

### `MenuItem`

```swift
struct MenuItem: Sendable, Identifiable {
    let id: String
    let icon: String                     // SF Symbol name
    let title: String
    let badge: String?                   // optional badge text
    let action: @Sendable () -> Void
    let routePath: String?               // navigate on tap
    let requiredPermission: String?      // permission gate
    let order: Int                       // sort order (lower = higher)
}
```

### `PluginRegistry`

```swift
@MainActor final class PluginRegistry {
    func register(_ plugin: Plugin) throws
    func status(of name: String) -> PluginStatus?
    func all() -> [(name: String, status: PluginStatus)]
    func install(_ name: String, _ sdk: PlatformSDK) async throws
    func installAll(_ sdk: PlatformSDK, enabled: Set<String>? = nil) async throws
    func activate(_ name: String) async throws
    func deactivate(_ name: String) async throws
    func uninstall(_ name: String) async throws
}
```

### Plugin Manifest

```swift
struct PluginManifest: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Sendable {
        let enabled: Bool
        let version: String
        let installedAt: String?
        let source: String
    }
    let plugins: [String: Entry]
    var enabledNames: Set<String> { get }
    func isEnabled(_ name: String) -> Bool
    static let empty: PluginManifest
}

protocol PluginManifestLoader: AnyObject, Sendable {
    func load() async -> PluginManifest
}

final class BundledPluginManifestLoader: PluginManifestLoader { ... }
final class RemotePluginManifestLoader: PluginManifestLoader { ... }
final class InMemoryPluginManifestLoader: PluginManifestLoader { ... }
```

---

## Registries

### `ComponentRegistry`

```swift
typealias ComponentFactory = () -> AnyView

final class ComponentRegistry {
    func add(_ name: String, _ factory: @escaping ComponentFactory)
    func remove(_ name: String)
    func get(_ name: String) -> ComponentFactory?
    func all() -> [String: ComponentFactory]
    func names() -> [String]
    func dashboardComponents() -> [(name: String, factory: ComponentFactory)]  // Dashboard* prefix
    func profileComponents() -> [(name: String, factory: ComponentFactory)]    // Profile* prefix
}
```

### `RouteRegistry`

```swift
final class RouteRegistry {
    func add(_ route: PluginRoute) throws   // rejects duplicate path or name
    func all() -> [PluginRoute]
}
```

### `StoreRegistry`

```swift
final class StoreRegistry {
    func create(_ id: String, _ store: AnyObject) throws  // rejects duplicate ID
    func get(_ id: String) -> AnyObject?
    func all() -> [String: AnyObject]
}
```

### `LocalizationRegistry`

```swift
final class LocalizationRegistry {
    func add(_ locale: String, _ messages: [String: String])  // deep-merges
    func all() -> [String: [String: String]]
    func t(_ key: String, locale: String) -> String           // returns key on miss
}
```

### `MenuItemRegistry`

```swift
final class MenuItemRegistry: @unchecked Sendable {
    func add(_ item: MenuItem)
    func remove(_ id: String)
    func all() -> [MenuItem]          // sorted by order
    func get(_ id: String) -> MenuItem?
}
```

### `RegistryError`

```swift
enum RegistryError: Error, Equatable {
    case duplicateRoutePath(String)
    case duplicateRouteName(String)
    case duplicateStoreId(String)
}
```

---

## Themes

### `AppTheme` (protocol)

```swift
protocol AppTheme: Identifiable, Sendable {
    var id: String { get }
    var displayName: String { get }
    var accent: Color { get }
    var background: Color { get }
    var cardBackground: Color { get }
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var destructive: Color { get }
    var success: Color { get }
    var separator: Color { get }
    var menuBackground: Color { get }
    var avatarBackground: Color { get }
    var preferredColorScheme: ColorScheme? { get }
}
```

### Built-in Themes

| Theme | ID | Color Scheme |
|-------|----|-------------|
| `ClassicTheme` | `"classic"` | System-adaptive (nil) |
| `DarkBlueTheme` | `"dark-blue"` | `.dark` — navy + blue accent |
| `DarkGreenTheme` | `"dark-green"` | `.dark` — dark + emerald accent |

### `ThemeRegistry`

```swift
final class ThemeRegistry: @unchecked Sendable {
    var defaultThemeID: String           // "classic"
    var themes: [any AppTheme]           // sorted by displayName
    init()                               // auto-registers 3 built-in themes
    func register(_ theme: any AppTheme) // replaces existing by ID
    func theme(for id: String) -> (any AppTheme)?
}
```

### `ThemeManager`

```swift
@MainActor final class ThemeManager: ObservableObject {
    @Published private(set) var currentTheme: any AppTheme
    init(registry: ThemeRegistry, defaults: UserDefaults = .standard)
    func selectTheme(_ id: String)       // persists to UserDefaults
}
```

### Environment Access

```swift
@Environment(\.appTheme) var theme    // default: ClassicTheme()
```

---

## Composition

### `SDKContainer`

```swift
@MainActor final class SDKContainer {
    nonisolated static let defaultBaseURL: URL   // https://vbwd.cc/api/v1
    let config: APIClientConfig
    let session: AuthSession
    let themeRegistry: ThemeRegistry
    let themeManager: ThemeManager

    init(baseURL: URL = defaultBaseURL, tokenStore: TokenStore? = nil)

    func makeLoginViewModel() -> LoginViewModel
    func makeDashboardViewModel(user: AuthUser, components: ComponentRegistry? = nil) -> DashboardViewModel
    func makeProfileViewModel() -> ProfileViewModel
    func makePluginHost(plugins: [Plugin],
                        manifestLoader: PluginManifestLoader? = nil,
                        manifestPath: String = "/admin/frontend-plugins/user",
                        fallback: PluginManifest = .empty) -> PluginHost
}
```

### `PluginHost`

```swift
@MainActor final class PluginHost: ObservableObject {
    let sdk: DefaultPlatformSDK
    private(set) var routes: [PluginRoute]
    private(set) var manifest: PluginManifest
    @Published var selectedRoute: String?
    var components: ComponentRegistry { get }

    init(api: APIClient, manifestLoader: PluginManifestLoader, plugins: [Plugin])
    func bootstrap() async
    func status(of name: String) -> PluginStatus?
}
```

---

## UI

### `AppRoot`

Full app shell with plugin support, burger menu, and theming.

```swift
@MainActor struct AppRoot: View {
    init(container: SDKContainer, plugins: [Plugin], manifestLoader: PluginManifestLoader? = nil)
}
```

### `RootView`

Simple auth-guard root without plugins.

```swift
struct RootView: View {
    init(container: SDKContainer)
}
```

### `LoginView`

```swift
struct LoginView: View {
    init(viewModel: LoginViewModel)
}
```

### `LoginViewModel`

```swift
@MainActor final class LoginViewModel: ObservableObject {
    @Published var email: String
    @Published var password: String
    @Published private(set) var isLoading: Bool
    @Published private(set) var errorMessage: String?
    var canSubmit: Bool { get }
    init(session: AuthSession)
    func submit() async
}
```

### `DashboardView`

```swift
struct DashboardView: View {
    init(viewModel: DashboardViewModel)
}
```

### `DashboardViewModel`

```swift
@MainActor final class DashboardViewModel: ObservableObject {
    @Published private(set) var isLoading: Bool
    @Published private(set) var errorMessage: String?
    @Published private(set) var invoices: [Invoice]
    @Published private(set) var tokenTransactions: [TokenTransaction]
    @Published private(set) var tokenBalance: Double
    var pluginWidgets: [(name: String, factory: ComponentFactory)] { get }
    var userName: String { get }
    var userEmail: String { get }
    var userInitials: String { get }
    var showTokenCard: Bool { get }
    var showInvoicesCard: Bool { get }
    var recentInvoices: [Invoice] { get }
    init(user: AuthUser, api: APIClient, endpoints: DashboardEndpoints = DashboardEndpoints(),
         evaluator: PermissionEvaluator = PermissionEvaluator(), components: ComponentRegistry? = nil)
    func load() async
    func retry() async
}
```

### `Navigator`

```swift
enum RouteResolution: Equatable {
    case allow, redirectToLogin, forbidden, notFound
}

enum Navigator {
    static func resolve(path: String, routes: [PluginRoute], isAuthenticated: Bool,
                        userPermissions: [String],
                        evaluator: PermissionEvaluator = PermissionEvaluator()) -> RouteResolution
}
```

### `RootRouter`

```swift
enum RootRoute: Equatable {
    case login, loading, dashboard(AuthUser)
}

enum RootRouter {
    static func route(for state: AuthState) -> RootRoute
}
```

### Side Menu Views

```swift
struct SideMenu: View {
    init(onClose: @escaping () -> Void)
}

struct BurgerMenuContainer<Content: View>: View {
    init(@ViewBuilder content: () -> Content)
}

struct MenuHeader: View {
    init(user: AuthUser?)
}

struct MenuItemButton: View {
    init(icon: String, title: String, badge: String? = nil,
         isDestructive: Bool = false, action: @escaping () -> Void)
}

struct PluginMenuItems: View {
    init(onClose: @escaping () -> Void)
}
```

### Environment Values

```swift
// Theme access
@Environment(\.appTheme) var theme

// Menu open state
@Environment(\.isMenuOpen) var isMenuOpen  // Binding<Bool>
```
