# VBWDCore Architecture

## Overview

VBWDCore is a modular iOS SDK that provides authentication, navigation, dashboard, profile management, and a plugin system for building SaaS applications. It follows SOLID principles and mirrors the architecture of the web SDK (`vbwd-fe-core`).

## Three-Layer Model

```
┌─────────────────────────────────┐
│         Host App (vbwd-ios)     │  Your app's @main entry point
│  - VBWDApp.swift                │  Imports VBWDCore + plugin modules
│  - plugins.json                 │  Plugin enable/disable config
└──────────────┬──────────────────┘
               │ uses
┌──────────────▼──────────────────┐
│        Plugins (separate repos) │  Each plugin is a Swift package
│  - ExamplePlugin                │  Depends only on VBWDCore
│  - BookingPlugin                │  Registers routes, widgets, etc.
│  - PaymentPlugin                │  via PlatformSDK facade
└──────────────┬──────────────────┘
               │ depends on
┌──────────────▼──────────────────┐
│        VBWDCore (this SDK)      │  Public module: VBWDCore
│  - Networking, Auth, Events     │  Protocols + default implementations
│  - Plugin system, Themes        │  Composition root: SDKContainer
│  - UI: Login, Dashboard, etc.   │  SOLID, TDD, Swift 6 concurrency
└─────────────────────────────────┘
```

## Module Layers

### 1. Networking Layer

Provides HTTP communication with the backend API.

| Type | Role |
|------|------|
| `APIClient` (protocol) | HTTP verb methods: `get`, `post`, `put`, `patch`, `delete` |
| `URLSessionAPIClient` | Production implementation using `URLSession` |
| `APIClientConfig` | Base URL, timeout, default headers |
| `APIError` | Typed errors: `.http`, `.transport`, `.decoding` |
| `AuthTokenProvider` | Injects bearer token into requests |
| `EmptyResponse` | Decode target for no-body endpoints |

All domain code depends on the `APIClient` protocol, not `URLSessionAPIClient`.

### 2. Persistence Layer

Stores authentication tokens securely.

| Type | Role |
|------|------|
| `TokenStore` (protocol) | Save/load token, refresh token, and user blob |
| `KeychainTokenStore` | Production: stores in iOS Keychain |
| `InMemoryTokenStore` | Tests/previews: stores in memory |

### 3. Domain Layer

Business logic and data models — no UI imports.

| Type | Role |
|------|------|
| `AuthService` (protocol) | Login, logout, session restore, profile fetch |
| `DefaultAuthService` | Implementation wired to `APIClient` + `TokenStore` |
| `ProfileService` (protocol) | Fetch/update profile, change password |
| `DefaultProfileService` | Implementation wired to `APIClient` |
| `AuthUser` | User model (id, email, name, role, permissions) |
| `UserProfile` | Editable profile fields (name, address, company) |
| `Credentials` | Login payload (email, password) |
| `PermissionEvaluator` | Permission checking with wildcard support |
| `AuthEndpoints` / `ProfileEndpoints` / `DashboardEndpoints` | Configurable API paths |

### 4. Session Layer

Manages authentication state reactively.

| Type | Role |
|------|------|
| `AuthState` (enum) | `.signedOut`, `.authenticating`, `.authenticated(AuthUser)`, `.error(String)` |
| `AuthSession` | `@MainActor ObservableObject` — drives the auth UI flow |

### 5. Events Layer

Decoupled communication between components.

| Type | Role |
|------|------|
| `EventBus` (protocol) | Pub/sub: `emit`, `on`, `once`, `off` |
| `DefaultEventBus` | Actor-safe implementation with backend forwarding |
| `AppEvents` | 40+ predefined event name constants |

Events marked `localOnly` (UI events like `notificationShow`) are not forwarded to the backend.

### 6. Plugin System

Extensibility framework for third-party features.

| Type | Role |
|------|------|
| `Plugin` (protocol) | Lifecycle: `install`, `activate`, `deactivate`, `uninstall` |
| `PluginMetadata` | Name, version, description, author, dependencies, translations |
| `PlatformSDK` (protocol) | Facade for plugin registration APIs |
| `DefaultPlatformSDK` | Concrete facade delegating to registries |
| `PluginRegistry` | Manages plugin lifecycle with topological sorting |
| `PluginManifest` | Enable/disable config (decoded from JSON) |
| `PluginManifestLoader` | Protocol for loading manifests (bundled, remote, in-memory) |

#### Registries

| Registry | Manages |
|----------|---------|
| `RouteRegistry` | Navigable screens (path + name uniqueness enforced) |
| `ComponentRegistry` | Named view factories (`Dashboard*`, `Profile*` conventions) |
| `StoreRegistry` | Observable state objects (ID uniqueness enforced) |
| `LocalizationRegistry` | Localised string dictionaries |
| `MenuItemRegistry` | Side menu items (sorted by `order`) |

#### Theme System

| Type | Role |
|------|------|
| `AppTheme` (protocol) | Color properties: accent, background, text, etc. |
| `ThemeRegistry` | Registers/retrieves themes (OCP extension point) |
| `ThemeManager` | Persists selected theme to UserDefaults |
| `ClassicTheme` | System-adaptive light/dark theme |
| `DarkBlueTheme` | Navy + blue accent |
| `DarkGreenTheme` | Dark + emerald accent |

### 7. Composition Layer

Wires everything together.

| Type | Role |
|------|------|
| `SDKContainer` | Composition root — the only place that names concrete types |
| `PluginHost` | Bootstraps plugins: load manifest → register → install → activate |

`SDKContainer` creates:
- `URLSessionAPIClient` with config
- `KeychainTokenStore` (or injected `TokenStore`)
- `AuthSession` with `DefaultAuthService`
- `ThemeRegistry` + `ThemeManager`

`PluginHost` orchestrates:
- Manifest loading (bundled or remote)
- Plugin registration and dependency validation
- Error-isolated installation (one plugin failing doesn't block others)
- Route and component aggregation for the UI

### 8. UI Layer

SwiftUI views — all `internal` except entry points.

| View | Role |
|------|------|
| `AppRoot` | Full app shell: plugin host + burger menu + theme + routing |
| `RootView` | Simpler root without plugins (auth guard only) |
| `LoginView` / `LoginViewModel` | Email/password login form |
| `DashboardView` / `DashboardViewModel` | Dashboard with cards + plugin widgets |
| `ProfileEditView` / `ProfileViewModel` | Profile editor + plugin sections |
| `SettingsScreen` | Theme picker |
| `SideMenu` | Full side-drawer with core + plugin items |
| `BurgerMenuContainer` | Slide-in overlay container |
| `Navigator` | Route resolution (auth, permissions, 404) |
| `RootRouter` | Maps `AuthState` → `RootRoute` |

---

## SOLID Principles in Practice

### Single Responsibility (SRP)
- Each file has one job: `AuthService` handles auth logic, `AuthSession` holds state, `LoginView` renders UI, `LoginViewModel` mediates
- Plugin entry points are thin composition roots — no business logic

### Open/Closed (OCP)
- The app is extended through SDK seams (`addRoute`, `addComponent`, `addMenuItem`) without modifying core code
- `ThemeRegistry.register()` adds themes without touching existing ones
- `PluginRegistry.register()` adds plugins without touching the host

### Liskov Substitution (LSP)
- Every plugin passes the same `Plugin` contract
- `InMemoryTokenStore` can replace `KeychainTokenStore` without code changes
- `SpyAPIClient` (test kit) replaces `URLSessionAPIClient` in tests

### Interface Segregation (ISP)
- `APIClient` exposes only HTTP verbs — not `URLSession` internals
- `PlatformSDK` exposes only registration APIs — not registry internals
- `PermissionEvaluator` takes `[String]`, not `AuthUser`

### Dependency Inversion (DIP)
- All domain code depends on protocols (`APIClient`, `TokenStore`, `AuthService`)
- `SDKContainer` is the single composition root that names concrete types
- Plugins receive `PlatformSDK` (protocol), not `DefaultPlatformSDK`

---

## Concurrency Model

VBWDCore uses Swift 6 strict concurrency:

| Pattern | Where |
|---------|-------|
| `@MainActor` classes | `AuthSession`, `PluginHost`, `PluginRegistry`, `ThemeManager`, all ViewModels |
| `@unchecked Sendable` | `URLSessionAPIClient`, `DefaultAuthService`, `KeychainTokenStore` (thread-safe via internal locking) |
| Internal `actor` | `DefaultEventBus` uses `actor State` for listener/history management |
| `nonisolated init()` | Required on plugin classes and stores for cross-actor instantiation |

---

## Web Parity

VBWDCore mirrors the TypeScript `vbwd-fe-core` SDK:

| Concept | Web (TypeScript) | iOS (Swift) |
|---------|-------------------|-------------|
| Plugin protocol | `IPlugin` interface | `Plugin` protocol |
| SDK facade | `PlatformSDK` class | `PlatformSDK` protocol |
| Plugin registry | `PluginRegistry` class | `PluginRegistry` class |
| Route registration | `sdk.addRoute()` | `sdk.addRoute()` |
| Component slots | `sdk.addComponent()` | `sdk.addComponent()` |
| State stores | `sdk.createStore()` (Pinia) | `sdk.createStore()` (ObservableObject) |
| Event bus | `sdk.events.on/emit` | `sdk.events.on/emit` |
| i18n | `sdk.addTranslations()` | `sdk.addTranslations()` |
| Manifest loader | Backend JSON | `PluginManifestLoader` (bundled/remote) |
| Plugin config | `plugins.json` | `plugins.json` |
| Event names | `AppEvents` constants | `AppEvents` constants |
| API paths | Configurable endpoints | Configurable endpoints structs |
