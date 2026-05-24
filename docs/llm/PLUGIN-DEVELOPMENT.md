# VBWD iOS Plugin Development — LLM Agent Instructions

Structured context for LLM coding agents to generate correct VBWDCore plugins.

## System Context

- **SDK**: `VBWDCore` (Swift Package, Swift 6, strict concurrency)
- **Platforms**: iOS 16+, macOS 13+
- **Architecture**: Plugin system with SOLID principles, TDD
- **Host app**: `vbwd-ios` (SwiftUI app using `AppRoot` from VBWDCore)
- **Plugin repo naming**: `vbwd-ios-plugin-{name}`
- **GitHub org**: `VBWD-platform`

## Critical Rules

1. **ONLY import `VBWDCore`** — never import SDK internals or other targets
2. **Use `@unchecked Sendable`** on the Plugin class (Swift 6 concurrency)
3. **Use `nonisolated` on `init()`** for plugin and store classes
4. **Dashboard widget names MUST start with `Dashboard`** (e.g. `DashboardMyWidget`)
5. **Profile section names MUST start with `Profile`** (e.g. `ProfileMySection`)
6. **Plugin `metadata.name`** must be unique, lowercase, kebab-case
7. **Route paths** must be unique and start with `/`
8. **Menu item IDs** must be unique strings
9. **Store IDs** must be unique strings
10. **Profile sections should return `Section` views** for Form integration

## Package.swift Template

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "VBWD{PluginName}Plugin",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "{PluginName}Plugin", targets: ["{PluginName}Plugin"]),
    ],
    dependencies: [
        .package(path: "../vbwd-ios-core"),
    ],
    targets: [
        .target(
            name: "{PluginName}Plugin",
            dependencies: [
                .product(name: "VBWDCore", package: "vbwd-ios-core"),
            ],
            path: "Sources/{PluginName}Plugin",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

## File Structure (always follow this)

```
Sources/{PluginName}Plugin/
├── {PluginName}Plugin.swift        # Composition root (registration only)
├── {PluginName}MenuItems.swift     # Menu item factory
├── Domain/
│   ├── {PluginName}Store.swift     # @MainActor ObservableObject
│   └── {PluginName}Service.swift   # Protocol + default implementation
└── Views/
    ├── {PluginName}Screen.swift    # Main screen (route: /{name})
    ├── {PluginName}DashboardWidget.swift  # Dashboard* component
    └── {PluginName}ProfileSection.swift   # Profile* component
```

## Plugin Entry Point Template

```swift
import SwiftUI
import VBWDCore

public final class {PluginName}Plugin: Plugin, @unchecked Sendable {
    public let store = {PluginName}Store()
    private let unsubscribeBox = UnsubscribeBox()

    nonisolated public init() {}

    public var metadata: PluginMetadata {
        PluginMetadata(
            name: "{plugin-name}",  // kebab-case, unique
            version: SemanticVersion(1, 0, 0),
            description: "Description of what the plugin does.",
            author: "Author Name",
            keywords: ["keyword1", "keyword2"],
            dependencies: .none,
            translations: ["en": ["{plugin-name}.title": "Plugin Title"]]
        )
    }

    public func install(_ sdk: PlatformSDK) async throws {
        // Routes
        try sdk.addRoute(PluginRoute(
            path: "/{plugin-name}",
            name: "{plugin-name}",
            view: { AnyView({PluginName}Screen()) }))

        // Dashboard widget (MUST start with "Dashboard")
        sdk.addComponent("Dashboard{PluginName}") {
            AnyView({PluginName}DashboardWidget())
        }

        // Profile section (MUST start with "Profile")
        sdk.addComponent("Profile{PluginName}") {
            AnyView({PluginName}ProfileSection())
        }

        // Store
        try sdk.createStore("{pluginName}Store", store)

        // Translations
        sdk.addTranslations("en", ["{plugin-name}.title": "Plugin Title"])

        // Event subscription
        unsubscribeBox.unsubscribe = sdk.events.on(AppEvents.authLogin) { [weak store] _ in
            Task { @MainActor in
                store?.onUserLoggedIn()
            }
        }

        // Service (DIP — depends on protocol, not concrete)
        let service = {PluginName}Service(api: sdk.api)
        _ = await service.fetchData()

        // Menu items (delegated to factory)
        let items = await MainActor.run {
            {PluginName}MenuItems.all(store: store)
        }
        for item in items { sdk.addMenuItem(item) }
    }

    public func activate() async throws {
        await MainActor.run { store.setActive(true) }
    }

    public func deactivate() async throws {
        await MainActor.run { store.setActive(false) }
    }

    public func uninstall() async throws {
        unsubscribeBox.unsubscribe?()
        await MainActor.run { store.setActive(false) }
    }
}

private final class UnsubscribeBox: @unchecked Sendable {
    var unsubscribe: Unsubscribe?
}
```

## Store Template

```swift
import Foundation

@MainActor
public final class {PluginName}Store: ObservableObject {
    @Published public var active = false
    @Published public var data: [String] = []

    nonisolated public init() {}

    public func setActive(_ value: Bool) { active = value }
    public func onUserLoggedIn() { /* handle login */ }
}
```

## Service Template

```swift
import Foundation
import VBWDCore

public protocol {PluginName}ServiceProtocol: Sendable {
    func fetchData() async -> Bool
}

public final class {PluginName}Service: {PluginName}ServiceProtocol, @unchecked Sendable {
    private let api: APIClient

    public init(api: APIClient) { self.api = api }

    public func fetchData() async -> Bool {
        let result: EmptyResponse? = try? await api.get("/your-endpoint")
        return result != nil
    }
}
```

## View Templates

### Dashboard Widget

```swift
import SwiftUI

struct {PluginName}DashboardWidget: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "your.icon")
                    .foregroundColor(.blue)
                Text("Your Plugin")
                    .font(.headline)
            }
            Text("Widget content here")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
    }
}
```

### Profile Section

```swift
import SwiftUI

struct {PluginName}ProfileSection: View {
    var body: some View {
        Section("Your Plugin") {
            HStack {
                Text("Setting")
                Spacer()
                Text("Value").foregroundColor(.secondary)
            }
        }
    }
}
```

### Screen

```swift
import SwiftUI

struct {PluginName}Screen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Your Plugin").font(.largeTitle).bold()
                Text("Screen content").foregroundColor(.secondary)
            }
            .padding(24)
        }
    }
}
```

## Menu Items Template

```swift
import VBWDCore

enum {PluginName}MenuItems {
    @MainActor
    static func all(store: {PluginName}Store) -> [MenuItem] {
        [
            MenuItem(
                id: "{plugin-name}-home",
                icon: "your.icon",
                title: "Your Feature",
                routePath: "/{plugin-name}",
                order: 50
            ),
        ]
    }
}
```

## Available SDK APIs (PlatformSDK)

| Method | Purpose |
|--------|---------|
| `sdk.addRoute(PluginRoute)` | Register a navigable screen |
| `sdk.addComponent(String, ComponentFactory)` | Register a named view factory |
| `sdk.removeComponent(String)` | Remove a registered component |
| `sdk.createStore(String, AnyObject)` | Register an observable store |
| `sdk.addTranslations(String, [String: String])` | Add localised strings |
| `sdk.addMenuItem(MenuItem)` | Add a side menu item |
| `sdk.removeMenuItem(String)` | Remove a menu item by ID |
| `sdk.events.on(String, callback)` | Subscribe to events |
| `sdk.events.emit(String, Any?)` | Emit an event |
| `sdk.api.get(String)` | GET request via shared client |
| `sdk.api.post(String, body)` | POST request via shared client |
| `sdk.api.put(String, body)` | PUT request via shared client |
| `sdk.api.delete(String)` | DELETE request via shared client |

## Available Events (AppEvents)

| Event | Payload | When |
|-------|---------|------|
| `AppEvents.authLogin` | `nil` | User logged in |
| `AppEvents.authLogout` | `nil` | User logged out |
| `AppEvents.authTokenRefreshed` | `nil` | Token refreshed |
| `AppEvents.authSessionExpired` | `nil` | Session expired |
| `AppEvents.pluginError` | `String` | A plugin failed |
| `AppEvents.userUpdated` | `nil` | User profile updated |
| `AppEvents.subscriptionCreated` | `nil` | Subscription created |
| `AppEvents.paymentSucceeded` | `nil` | Payment completed |

## Key Types

| Type | Module | Purpose |
|------|--------|---------|
| `Plugin` | VBWDCore | Protocol all plugins implement |
| `PluginMetadata` | VBWDCore | Name, version, description, deps |
| `SemanticVersion` | VBWDCore | Semver type (Major, Minor, Patch) |
| `PlatformSDK` | VBWDCore | Facade for all SDK registration APIs |
| `PluginRoute` | VBWDCore | Route definition (path, name, auth, view) |
| `MenuItem` | VBWDCore | Menu item (id, icon, title, route/action) |
| `ComponentFactory` | VBWDCore | `() -> AnyView` closure type |
| `APIClient` | VBWDCore | Protocol for HTTP requests |
| `EventBus` | VBWDCore | Protocol for event pub/sub |
| `Unsubscribe` | VBWDCore | `() -> Void` closure from event subscription |
| `EmptyResponse` | VBWDCore | Empty Codable for fire-and-forget requests |
| `PluginDependencies` | VBWDCore | `.none`, `.list([String])`, `.constrained([String: String])` |
| `BundledPluginManifestLoader` | VBWDCore | Loads plugins.json from app bundle |
| `AppTheme` | VBWDCore | Protocol for theme color properties |
| `ThemeRegistry` | VBWDCore | Register custom themes |

## Naming Conventions

| Item | Convention | Example |
|------|-----------|---------|
| Plugin class | `{Name}Plugin` | `BookingPlugin` |
| Plugin metadata name | kebab-case | `"booking"` |
| Store class | `{Name}Store` | `BookingStore` |
| Service protocol | `{Name}ServiceProtocol` | `BookingServiceProtocol` |
| Dashboard widget | `Dashboard{Name}` | `DashboardBooking` |
| Profile section | `Profile{Name}` | `ProfileBooking` |
| Route path | `/{name}` | `/booking` |
| Menu item ID | `{name}-{feature}` | `booking-calendar` |
| Store ID | `{name}Store` | `bookingStore` |
| Translation keys | `{name}.{key}` | `booking.title` |

## Host App Integration

After creating the plugin, the host app developer must:

1. Add the plugin package as a submodule or local dependency
2. Import the plugin module in `VBWDApp.swift`
3. Add `YourPlugin()` to the `plugins:` array in `AppRoot`
4. Add entry in `plugins.json` with `"enabled": true`

## Common Mistakes to Avoid

- Importing anything other than `VBWDCore`
- Using `import Combine` when async/await suffices
- Forgetting `nonisolated` on `init()`
- Forgetting `@unchecked Sendable` on the Plugin class
- Dashboard component names not starting with `Dashboard`
- Profile component names not starting with `Profile`
- Putting business logic in the Plugin entry point (violates SRP)
- Making views `public` when they're only used internally
- Using raw property mutation on store instead of named methods
- Forgetting to call `unsubscribe` in `uninstall()`
- Using `@StateObject` or `@ObservedObject` for the store in the plugin class (use `let`)
