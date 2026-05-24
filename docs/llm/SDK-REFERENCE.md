# VBWDCore SDK Reference — LLM Agent Instructions

This document provides structured context for LLM coding agents to correctly build iOS apps on top of the VBWDCore SDK.

## System Context

- **SDK**: `VBWDCore` (Swift Package, Swift 6, strict concurrency)
- **Platforms**: iOS 16+, macOS 13+
- **Import**: `import VBWDCore` — the only public module
- **Architecture**: Layered (Networking → Domain → Session → Events → Plugins → Composition → UI)
- **Composition root**: `SDKContainer` — the single site naming concrete types
- **Concurrency**: `@MainActor` for all UI/state classes, `@unchecked Sendable` for thread-safe types

## Critical Rules

1. **ONLY import `VBWDCore`** — never import individual source files or internal modules
2. **Use `SDKContainer`** as the composition root — never instantiate `URLSessionAPIClient` or `KeychainTokenStore` directly
3. **Use `AppRoot`** for full plugin-powered apps, `RootView` for simple auth-only apps
4. **Use `BundledPluginManifestLoader`** for offline-first plugin config
5. **All ViewModels are `@MainActor`** — never access from background threads
6. **Endpoint paths are configurable** via `AuthEndpoints`, `ProfileEndpoints`, `DashboardEndpoints`
7. **Theme access**: `@Environment(\.appTheme) var theme` — use `theme.accent`, `theme.background`, etc.
8. **Session state**: `AuthSession.state` is the source of truth — observe via `@EnvironmentObject`

## Minimal Host App Template

```swift
import SwiftUI
import VBWDCore

@main
struct MyApp: App {
    @MainActor private static let container = SDKContainer()

    var body: some Scene {
        WindowGroup {
            AppRoot(
                container: MyApp.container,
                plugins: [],
                manifestLoader: BundledPluginManifestLoader()
            )
        }
    }
}
```

Required bundle resource — `plugins.json`:
```json
{
  "plugins": {}
}
```

## Host App with Plugins

```swift
import SwiftUI
import VBWDCore
import BookingPlugin
import PaymentPlugin

@main
struct MyApp: App {
    @MainActor private static let container = SDKContainer()

    var body: some Scene {
        WindowGroup {
            AppRoot(
                container: MyApp.container,
                plugins: [BookingPlugin(), PaymentPlugin()],
                manifestLoader: BundledPluginManifestLoader()
            )
        }
    }
}
```

`plugins.json`:
```json
{
  "plugins": {
    "booking": { "enabled": true, "version": "1.0.0", "source": "local" },
    "payment": { "enabled": true, "version": "1.0.0", "source": "local" }
  }
}
```

## Custom Backend URL

```swift
@MainActor private static let container = SDKContainer(
    baseURL: URL(string: "https://api.example.com/api/v1")!
)
```

Default: `https://vbwd.cc/api/v1`

## SDKContainer API

```swift
@MainActor final class SDKContainer {
    nonisolated static let defaultBaseURL: URL

    let config: APIClientConfig
    let session: AuthSession
    let themeRegistry: ThemeRegistry
    let themeManager: ThemeManager

    init(baseURL: URL = defaultBaseURL, tokenStore: TokenStore? = nil)

    func makeLoginViewModel() -> LoginViewModel
    func makeDashboardViewModel(user: AuthUser, components: ComponentRegistry?) -> DashboardViewModel
    func makeProfileViewModel() -> ProfileViewModel
    func makePluginHost(plugins: [Plugin], manifestLoader: PluginManifestLoader?,
                        manifestPath: String, fallback: PluginManifest) -> PluginHost
}
```

## Key Types Quick Reference

### Auth

| Type | Purpose |
|------|---------|
| `AuthSession` | `@MainActor ObservableObject` — auth state machine |
| `AuthState` | `.signedOut`, `.authenticating`, `.authenticated(AuthUser)`, `.error(String)` |
| `AuthUser` | User model: id, email, name, role, permissions |
| `Credentials` | Login payload: email, password |
| `AuthService` | Protocol: login, logout, restore, fetchProfile |

### Networking

| Type | Purpose |
|------|---------|
| `APIClient` | Protocol: get, post, put, patch, delete |
| `APIClientConfig` | baseURL, timeout, headers |
| `APIError` | `.http(status:message:)`, `.transport`, `.decoding`, `.notImplemented` |
| `EmptyResponse` | Decode target for no-body endpoints |

### Persistence

| Type | Purpose |
|------|---------|
| `TokenStore` | Protocol: save/load token, refreshToken, user |
| `KeychainTokenStore` | Production Keychain implementation |
| `InMemoryTokenStore` | Test/preview implementation |

### Profile

| Type | Purpose |
|------|---------|
| `ProfileService` | Protocol: fetchProfile, updateDetails, changePassword |
| `UserProfile` | Editable profile fields (name, address, company) |
| `ProfileViewModel` | `@MainActor` form data + load/save/changePassword |

### Events

| Type | Purpose |
|------|---------|
| `EventBus` | Protocol: emit, on, once, off, sendToBackend |
| `DefaultEventBus` | Actor-safe impl with backend forwarding |
| `AppEvents` | 40+ event name constants |
| `Unsubscribe` | `@Sendable () -> Void` — call to unsubscribe |

### Plugins

| Type | Purpose |
|------|---------|
| `Plugin` | Protocol: metadata, install, activate, deactivate, uninstall |
| `PluginMetadata` | Name, version, description, author, dependencies, translations |
| `PlatformSDK` | Protocol: the facade plugins use for registration |
| `PluginRoute` | Route definition: path, name, requiresAuth, view factory |
| `MenuItem` | Menu item: id, icon, title, badge, routePath, order |
| `PluginRegistry` | Lifecycle manager with topological sorting |
| `PluginManifest` | Enable/disable config (decoded from JSON) |
| `BundledPluginManifestLoader` | Reads plugins.json from app bundle |
| `SemanticVersion` | Major.Minor.Patch with comparison |
| `VersionConstraint` | Semver constraint matching (^, ~, >=, etc.) |

### Registries

| Type | Purpose |
|------|---------|
| `ComponentRegistry` | Named view factories; `Dashboard*` and `Profile*` conventions |
| `RouteRegistry` | Unique path + name enforcement |
| `StoreRegistry` | Unique ID enforcement |
| `LocalizationRegistry` | Deep-merged i18n dictionaries |
| `MenuItemRegistry` | Sorted menu items |

### Themes

| Type | Purpose |
|------|---------|
| `AppTheme` | Protocol: accent, background, textPrimary, etc. |
| `ThemeRegistry` | Stores all themes; OCP extension point |
| `ThemeManager` | `@MainActor` — persists selection to UserDefaults |
| `ClassicTheme` | System-adaptive light/dark |
| `DarkBlueTheme` | Navy + blue accent |
| `DarkGreenTheme` | Dark + emerald accent |

### UI

| Type | Purpose |
|------|---------|
| `AppRoot` | Full app shell with plugins, burger menu, themes |
| `RootView` | Simple auth-guard root (no plugins) |
| `LoginView` | Email/password login form |
| `DashboardView` | Dashboard with cards + plugin widgets |
| `SideMenu` | Full side-drawer navigation |
| `Navigator` | Route resolution (auth, permissions, 404) |
| `RootRouter` | Maps AuthState → RootRoute |

### Composition

| Type | Purpose |
|------|---------|
| `SDKContainer` | Composition root — names all concrete types |
| `PluginHost` | `@MainActor` — bootstraps plugins end-to-end |

## Event Names

```swift
// Auth
AppEvents.authLogin           AppEvents.authLogout
AppEvents.authTokenRefreshed  AppEvents.authSessionExpired

// User
AppEvents.userRegistered      AppEvents.userUpdated
AppEvents.userDeleted

// Subscription
AppEvents.subscriptionCreated    AppEvents.subscriptionActivated
AppEvents.subscriptionUpgraded   AppEvents.subscriptionDowngraded
AppEvents.subscriptionCancelled  AppEvents.subscriptionExpired

// Payment
AppEvents.paymentInitiated    AppEvents.paymentSucceeded
AppEvents.paymentFailed       AppEvents.paymentRefunded

// Plugin
AppEvents.pluginRegistered    AppEvents.pluginInitialized
AppEvents.pluginError         AppEvents.pluginStopped
```

## Permissions

`PermissionEvaluator` supports:
- Exact match: `"subscription.invoices.view"`
- Namespace wildcard: `"subscription.*"` — matches any permission starting with `subscription.`
- Full wildcard: `"*"` — matches everything

Dashboard cards are gated:
- Token balance: requires `"subscription.tokens.view"`
- Invoices: requires `"subscription.invoices.view"`

## Configurable Endpoints

```swift
AuthEndpoints(login: "/auth/login", logout: "/auth/logout",
              refresh: "/auth/refresh", profile: "/user/profile")

ProfileEndpoints(profile: "/user/profile", updateDetails: "/user/details",
                 changePassword: "/user/change-password")

DashboardEndpoints(tokenBalance: "/user/tokens/balance",
                   tokenTransactions: "/user/tokens/transactions?limit=10",
                   invoices: "/invoices/")
```

## Package.swift for Host App (SPM)

```swift
dependencies: [
    .package(url: "https://github.com/VBWD-platform/vbwd-ios-core.git", from: "1.0.0"),
    .package(url: "https://github.com/VBWD-platform/vbwd-ios-plugin-example.git", from: "1.0.0"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "VBWDCore", package: "vbwd-ios-core"),
        .product(name: "ExamplePlugin", package: "vbwd-ios-plugin-example"),
    ]),
]
```

## Common Mistakes to Avoid

- Importing SDK internals instead of just `VBWDCore`
- Instantiating `URLSessionAPIClient` directly (use `SDKContainer`)
- Using `RootView` when plugins are needed (use `AppRoot`)
- Forgetting `plugins.json` in the app bundle
- Forgetting to add plugin to `plugins:` array in `AppRoot`
- Forgetting to enable plugin in `plugins.json`
- Using `@StateObject` for `SDKContainer` (use `static let` instead)
- Accessing `AuthSession` from background thread (it's `@MainActor`)
