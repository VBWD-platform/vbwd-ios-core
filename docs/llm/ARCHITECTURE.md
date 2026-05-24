# VBWDCore Architecture — LLM Agent Context

Structured architectural context for LLM coding agents working with the VBWDCore SDK.

## Three-Layer Model

```
Host App (vbwd-ios)        → imports VBWDCore + plugin modules
    ↓ uses
Plugins (separate repos)   → import VBWDCore only
    ↓ depends on
VBWDCore (this SDK)        → single public module
```

## Module Layers (dependency flows downward)

```
UI Layer
  ├── AppRoot, RootView (entry points)
  ├── LoginView, DashboardView, ProfileEditView, SettingsScreen
  ├── SideMenu, BurgerMenuContainer, Navigator, RootRouter
  └── ViewModels (LoginViewModel, DashboardViewModel, ProfileViewModel)

Composition Layer
  ├── SDKContainer (composition root — only place naming concrete types)
  └── PluginHost (bootstrap: manifest → register → install → activate)

Plugin System
  ├── Plugin protocol, PluginMetadata, PluginRegistry
  ├── PlatformSDK facade (routes, components, stores, i18n, menu items)
  ├── Registries (Route, Component, Store, Localization, MenuItem)
  └── Theme system (AppTheme protocol, ThemeRegistry, ThemeManager)

Events Layer
  ├── EventBus protocol, DefaultEventBus (actor-safe, backend forwarding)
  └── AppEvents (40+ event name constants)

Session Layer
  ├── AuthState enum (.signedOut, .authenticating, .authenticated, .error)
  └── AuthSession (@MainActor ObservableObject)

Domain Layer
  ├── AuthService protocol, DefaultAuthService
  ├── ProfileService protocol, DefaultProfileService
  ├── AuthUser, UserProfile, Credentials, LoginResponse
  ├── PermissionEvaluator (wildcard matching)
  └── Configurable endpoint structs

Persistence Layer
  ├── TokenStore protocol
  ├── KeychainTokenStore (production)
  └── InMemoryTokenStore (tests)

Networking Layer
  ├── APIClient protocol
  ├── URLSessionAPIClient (production, auto bearer token, 401 → tokenExpired)
  ├── APIClientConfig, APIError, HTTPMethod
  └── EmptyResponse
```

## SOLID Implementation

| Principle | How Applied |
|-----------|-------------|
| **S** Single Responsibility | Each file has one job. Store = state, Service = API, View = render, ViewModel = mediate, Plugin = wire |
| **O** Open/Closed | App extended via SDK seams (addRoute, addComponent, addMenuItem, register theme). Core never modified |
| **L** Liskov Substitution | Any Plugin implementation passes the same contract. InMemoryTokenStore replaces KeychainTokenStore |
| **I** Interface Segregation | APIClient exposes only HTTP verbs. PlatformSDK exposes only registration. PermissionEvaluator takes [String] |
| **D** Dependency Inversion | All domain code depends on protocols. SDKContainer is the single composition root naming concrete types |

## Concurrency Patterns

| Pattern | Where Used |
|---------|-----------|
| `@MainActor` class | AuthSession, PluginHost, PluginRegistry, ThemeManager, all ViewModels |
| `@unchecked Sendable` | URLSessionAPIClient, DefaultAuthService, KeychainTokenStore (thread-safe internals) |
| Internal `actor` | DefaultEventBus uses `actor State` for listener/history |
| `nonisolated init()` | Required on Plugin classes and Store classes for cross-actor instantiation |
| `@Sendable` closures | Event callbacks, MenuItem actions |

## Plugin Lifecycle

```
register(plugin)
    → status: .registered

installAll(sdk, enabled: manifest.enabledNames)
    → topological sort by dependencies
    → per-plugin error isolation (one failing → .error, others continue)
    → status: .installed

activate(name)
    → status: .active

deactivate(name)
    → guarded by active dependents
    → status: .inactive

uninstall(name)
    → cleanup
```

## Component Discovery Conventions

| Prefix | Discovered By | Rendered In |
|--------|---------------|-------------|
| `Dashboard*` | `ComponentRegistry.dashboardComponents()` | DashboardView — 2-column grid, 120pt height |
| `Profile*` | `ComponentRegistry.profileComponents()` | ProfileEditView — Form sections at bottom |

## Route Resolution

```swift
Navigator.resolve(path, routes, isAuthenticated, userPermissions)
    → .allow          // route found, no auth needed or auth+perms satisfied
    → .redirectToLogin // route requires auth, user not authenticated
    → .forbidden       // route requires permission user doesn't have
    → .notFound        // no route matches path
```

## Auth State Machine

```
.signedOut  ──signIn()──→  .authenticating  ──success──→  .authenticated(user)
                                             ──failure──→  .error(message)
.authenticated  ──signOut()──→  .signedOut

App launch: start() → restore() → .authenticated or .signedOut
```

## Event Bus Architecture

- `emit()` is fire-and-forget (never blocks the caller)
- Non-local events are forwarded to backend via `POST /events`
- Failed backend sends are retained and retried on `flushPending()`
- 6 UI-local events (notification, modal, loading) are never sent to backend
- History capped at `maxHistory` (default 100) records

## Theme Architecture

```
ThemeRegistry (holds all themes, OCP extension point)
       │
ThemeManager (@MainActor, reads/writes UserDefaults)
       │
Environment(\.appTheme) → all views
```

## File Organization in SDK

```
Sources/VBWDCore/
├── VBWDCore.swift                    # Namespace enum (apiContractVersion)
├── Networking/
│   ├── APIClient.swift               # Protocol
│   ├── URLSessionAPIClient.swift     # Production impl
│   ├── APIClientConfig.swift         # Config struct
│   ├── APIError.swift                # Error enum
│   ├── AuthTokenProvider.swift       # Token injection
│   └── HTTPMethod.swift              # Verb enum
├── Persistence/
│   ├── TokenStore.swift              # Protocol + InMemoryTokenStore
│   └── KeychainTokenStore.swift      # Keychain impl
├── Domain/
│   ├── AuthService.swift             # Protocol + DefaultAuthService
│   ├── AuthUser.swift                # User model
│   ├── Credentials.swift             # Login payload
│   ├── LoginResponse.swift           # API response
│   ├── ProfileService.swift          # Protocol + DefaultProfileService
│   ├── UserProfile.swift             # Profile model
│   ├── PermissionEvaluator.swift     # Wildcard permission matching
│   ├── AuthEndpoints.swift           # Configurable auth paths
│   ├── ProfileEndpoints.swift        # Configurable profile paths
│   └── DashboardModels.swift         # Invoice, TokenTransaction, endpoints
├── Session/
│   ├── AuthState.swift               # State enum
│   └── AuthSession.swift             # ObservableObject state machine
├── Events/
│   ├── EventBus.swift                # Protocol + DefaultEventBus
│   └── AppEvents.swift               # Event name constants
├── Plugins/
│   ├── Plugin.swift                  # Protocol + PluginMetadata + PluginStatus
│   ├── PlatformSDK.swift             # Facade protocol + DefaultPlatformSDK
│   ├── PluginRegistry.swift          # Lifecycle manager
│   ├── PluginManifest.swift          # Config + loaders
│   ├── PluginError.swift             # Error enum
│   ├── SemanticVersion.swift         # Semver + VersionConstraint
│   ├── AppShellMenuItem.swift        # MenuItem struct
│   ├── AppShellMenuItemRegistry.swift # MenuItemRegistry
│   ├── SideMenu.swift                # Side menu view
│   ├── BurgerMenuContainer.swift     # Overlay container
│   ├── MenuHeader.swift              # Avatar + user info
│   ├── MenuItemButton.swift          # Menu row button
│   ├── Registries/
│   │   ├── ComponentRegistry.swift   # Dashboard* / Profile* discovery
│   │   ├── RouteRegistry.swift       # Unique path/name enforcement
│   │   ├── StoreRegistry.swift       # Unique ID enforcement
│   │   └── LocalizationRegistry.swift # i18n merging
│   └── Theme/
│       ├── AppTheme.swift            # Protocol
│       ├── ClassicTheme.swift        # System-adaptive
│       ├── DarkBlueTheme.swift       # Navy + blue
│       ├── DarkGreenTheme.swift      # Dark + emerald
│       ├── ThemeEnvironment.swift    # SwiftUI environment key
│       ├── ThemeManager.swift        # Persisted selection
│       └── ThemeRegistry.swift       # Theme storage
├── Composition/
│   ├── SDKContainer.swift            # Composition root
│   ├── PluginHost.swift              # Plugin bootstrap
│   └── PluginMenuItems.swift         # Plugin menu items view
└── UI/
    ├── AppShell/
    │   ├── AppRoot.swift             # Full app with plugins
    │   ├── AppShellView.swift        # Navigation host
    │   ├── RootView.swift            # Simple auth root
    │   ├── Navigator.swift           # Route resolution
    │   ├── RootRouter.swift          # AuthState → RootRoute
    │   ├── Localization.swift        # i18n ObservableObject
    │   ├── MenuToolbar.swift         # Hamburger toolbar modifier
    │   ├── ProfileScreen.swift       # Read-only profile
    │   └── SettingsScreen.swift      # Theme picker
    ├── Login/
    │   ├── LoginView.swift
    │   └── LoginViewModel.swift
    ├── Dashboard/
    │   ├── DashboardView.swift
    │   ├── DashboardViewModel.swift
    │   └── DashboardWidgetLayout.swift
    └── Profile/
        ├── ProfileEditView.swift
        └── ProfileViewModel.swift
```

## Web Parity Table

| Concept | Web (TypeScript) | iOS (Swift) |
|---------|-----------------|-------------|
| Plugin interface | `IPlugin` | `Plugin` protocol |
| SDK facade | `PlatformSDK` class | `PlatformSDK` protocol |
| Plugin registry | `PluginRegistry` | `PluginRegistry` |
| Route registration | `sdk.addRoute()` | `sdk.addRoute()` |
| Component slots | `sdk.addComponent()` | `sdk.addComponent()` |
| State stores | `sdk.createStore()` (Pinia) | `sdk.createStore()` (ObservableObject) |
| Event bus | `sdk.events.on/emit` | `sdk.events.on/emit` |
| i18n | `sdk.addTranslations()` | `sdk.addTranslations()` |
| Manifest | Backend JSON | `PluginManifestLoader` |
| Plugin config | `plugins.json` | `plugins.json` |
| Event names | `AppEvents` | `AppEvents` |
| Permissions | Wildcard matching | `PermissionEvaluator` |
