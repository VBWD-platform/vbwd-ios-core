# Plugin Development Guide

This guide explains how to create, test, and ship a plugin for VBWDCore.

## What is a Plugin?

A plugin is a Swift package that extends a VBWDCore-powered app by registering routes, dashboard widgets, profile sections, menu items, translations, and state stores — all through the `PlatformSDK` facade.

Plugins:
- Depend only on the public `VBWDCore` module — never on SDK internals
- Are compiled into the host app at build time
- Are enabled/disabled via `plugins.json` (no recompilation needed)
- Are error-isolated — one plugin failing doesn't block the app

## Project Setup

### 1. Create a New Swift Package

```bash
mkdir vbwd-ios-plugin-yourname
cd vbwd-ios-plugin-yourname
```

### 2. Package.swift

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "VBWDYourPlugin",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "YourPlugin", targets: ["YourPlugin"]),
    ],
    dependencies: [
        .package(path: "../vbwd-ios-core"),
    ],
    targets: [
        .target(
            name: "YourPlugin",
            dependencies: [
                .product(name: "VBWDCore", package: "vbwd-ios-core"),
            ],
            path: "Sources/YourPlugin",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

### 3. Recommended File Structure

```
Sources/YourPlugin/
├── YourPlugin.swift              # Composition root (registration only)
├── YourMenuItems.swift           # Menu item factory
├── Domain/
│   ├── YourStore.swift           # @MainActor ObservableObject
│   └── YourService.swift         # Protocol + implementation (DIP)
└── Views/
    ├── YourScreen.swift           # Main screen (route: /your-plugin)
    ├── YourDashboardWidget.swift  # Dashboard widget (Dashboard* name)
    └── YourProfileSection.swift   # Profile section (Profile* name)
```

## Plugin Lifecycle

Plugins go through these states:

```
registered → installed → active
                       → inactive
                       → error(String)
```

### The Plugin Protocol

```swift
public protocol Plugin: AnyObject, Sendable {
    var metadata: PluginMetadata { get }
    func install(_ sdk: PlatformSDK) async throws
    func activate() async throws       // default: no-op
    func deactivate() async throws     // default: no-op
    func uninstall() async throws      // default: no-op
}
```

The host app calls these methods in order:
1. `register` — plugin is known to the registry
2. `install(_:)` — plugin registers its content via `PlatformSDK`
3. `activate()` — plugin is fully operational
4. `deactivate()` / `uninstall()` — cleanup

### Plugin Entry Point

```swift
import SwiftUI
import VBWDCore

public final class YourPlugin: Plugin, @unchecked Sendable {
    public let store = YourStore()
    private let unsubscribeBox = UnsubscribeBox()

    nonisolated public init() {}

    public var metadata: PluginMetadata {
        PluginMetadata(
            name: "your-plugin",               // unique, kebab-case
            version: SemanticVersion(1, 0, 0),
            description: "What the plugin does.",
            author: "Your Name",
            keywords: ["feature"],
            dependencies: .none,
            translations: ["en": ["your-plugin.title": "Your Plugin"]]
        )
    }

    public func install(_ sdk: PlatformSDK) async throws {
        // 1. Routes
        try sdk.addRoute(PluginRoute(
            path: "/your-plugin",
            name: "your-plugin",
            view: { AnyView(YourScreen()) }
        ))

        // 2. Dashboard widget (MUST start with "Dashboard")
        sdk.addComponent("DashboardYour") {
            AnyView(YourDashboardWidget())
        }

        // 3. Profile section (MUST start with "Profile")
        sdk.addComponent("ProfileYour") {
            AnyView(YourProfileSection())
        }

        // 4. Store
        try sdk.createStore("yourStore", store)

        // 5. Translations
        sdk.addTranslations("en", ["your-plugin.title": "Your Plugin"])

        // 6. Events
        unsubscribeBox.unsubscribe = sdk.events.on(AppEvents.authLogin) { [weak store] _ in
            Task { @MainActor in store?.onUserLoggedIn() }
        }

        // 7. Menu items
        let items = await MainActor.run { YourMenuItems.all(store: store) }
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

## Extension Points

### Routes

Register navigable screens:

```swift
// Basic route
try sdk.addRoute(PluginRoute(
    path: "/your-page",
    name: "your-page",
    view: { AnyView(YourPageView()) }
))

// Auth-gated route with permission check
try sdk.addRoute(PluginRoute(
    path: "/your-page/admin",
    name: "your-page-admin",
    requiresAuth: true,
    requiredUserPermission: "admin.view",
    view: { AnyView(AdminView()) }
))
```

### Dashboard Widgets

Register a component with a name starting with `Dashboard` — the SDK discovers it automatically and renders it in a 2-column grid on the dashboard.

```swift
sdk.addComponent("DashboardMyWidget") {
    AnyView(MyDashboardWidget())
}
```

Widget view:

```swift
struct MyDashboardWidget: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.fill").foregroundColor(.blue)
                Text("My Widget").font(.headline)
            }
            Text("Widget content").font(.caption).foregroundColor(.secondary)
        }
        .padding(16)
    }
}
```

### Profile Sections

Register a component with a name starting with `Profile` — it appears at the bottom of the profile edit form.

```swift
sdk.addComponent("ProfileMySection") {
    AnyView(MyProfileSection())
}
```

Profile sections should return a `Section` view for proper Form integration:

```swift
struct MyProfileSection: View {
    var body: some View {
        Section("My Plugin Settings") {
            HStack {
                Text("Setting")
                Spacer()
                Text("Value").foregroundColor(.secondary)
            }
        }
    }
}
```

### Menu Items

Add items to the side menu:

```swift
sdk.addMenuItem(MenuItem(
    id: "your-home",               // unique ID
    icon: "star.fill",             // SF Symbol name
    title: "Your Feature",
    badge: "NEW",                  // optional badge text
    routePath: "/your-plugin",     // navigate on tap
    requiredPermission: nil,       // optional permission gate
    order: 50                      // sort order (lower = higher)
))
```

### Stores

Register observable state:

```swift
@MainActor
public final class YourStore: ObservableObject {
    @Published public var items: [String] = []
    @Published public var active = false

    nonisolated public init() {}

    public func setActive(_ value: Bool) { active = value }
    public func onUserLoggedIn() { /* handle login */ }
}
```

Register in `install()`:

```swift
try sdk.createStore("yourStore", store)
```

### Translations

```swift
sdk.addTranslations("en", ["your.title": "Your Plugin", "your.desc": "Description"])
sdk.addTranslations("de", ["your.title": "Dein Plugin", "your.desc": "Beschreibung"])
```

### Event Bus

Subscribe to app-wide events:

```swift
let unsub = sdk.events.on(AppEvents.authLogin) { payload in
    print("User logged in")
}
// Store `unsub` to call in uninstall()
```

Available events: `authLogin`, `authLogout`, `authTokenRefreshed`, `authSessionExpired`, `pluginError`, and many more (see [API Reference](API-REFERENCE.md)).

### API Client

Make authenticated HTTP requests through the shared client:

```swift
let service = YourService(api: sdk.api)
let data: YourResponse = try await sdk.api.get("/your-endpoint")
```

## Naming Conventions

| Item | Convention | Example |
|------|-----------|---------|
| Plugin class | `{Name}Plugin` | `BookingPlugin` |
| Metadata name | kebab-case | `"booking"` |
| Store class | `{Name}Store` | `BookingStore` |
| Service protocol | `{Name}ServiceProtocol` | `BookingServiceProtocol` |
| Dashboard widget | `Dashboard{Name}` | `DashboardBooking` |
| Profile section | `Profile{Name}` | `ProfileBooking` |
| Route path | `/{name}` | `/booking` |
| Menu item ID | `{name}-{feature}` | `booking-calendar` |
| Store ID | `{name}Store` | `bookingStore` |
| Translation keys | `{name}.{key}` | `booking.title` |

## Dependencies Between Plugins

Plugins can declare dependencies on other plugins:

```swift
// Require another plugin (any version)
dependencies: .list(["other-plugin"])

// Require with version constraint
dependencies: .constrained(["other-plugin": ">=1.0.0"])
```

The SDK does topological sorting and validates semver constraints during `installAll()`.

## Testing

### Unit Test Your Store

```swift
let store = YourStore()
store.addItem("test")
assert(store.items.count == 1)
```

### Unit Test Your Service

```swift
let spy = SpyAPIClient()    // from VBWDCoreTestKit
let service = YourService(api: spy)
let result = await service.fetchData()
assert(result != nil)
```

### Test Plugin Registration

```swift
let sdk = DefaultPlatformSDK(
    api: SpyAPIClient(),
    events: DefaultEventBus(api: SpyAPIClient())
)
let plugin = YourPlugin()
try await plugin.install(sdk)

assert(sdk.getRoutes().contains { $0.path == "/your-plugin" })
assert(sdk.getComponents()["DashboardYour"] != nil)
assert(sdk.getComponents()["ProfileYour"] != nil)
assert(sdk.getMenuItems().contains { $0.id == "your-home" })
```

### Contract Test

Verify your plugin passes the full lifecycle:

```swift
let registry = PluginRegistry()
let plugin = YourPlugin()
try registry.register(plugin)
try await registry.installAll(sdk)

assert(registry.status(of: "your-plugin") == .installed)
try await registry.activate("your-plugin")
assert(registry.status(of: "your-plugin") == .active)
try await registry.deactivate("your-plugin")
assert(registry.status(of: "your-plugin") == .inactive)
```

## Host App Integration

After creating the plugin:

### 1. Add as a Git Submodule

```bash
cd your-app/Packages
git submodule add https://github.com/VBWD-platform/vbwd-ios-plugin-yourname.git
```

### 2. Add to Xcode

File > Add Package Dependencies > Add Local > select `Packages/vbwd-ios-plugin-yourname`

### 3. Import and Register

```swift
import VBWDCore
import YourPlugin

@main
struct MyApp: App {
    @MainActor private static let container = SDKContainer()

    var body: some Scene {
        WindowGroup {
            AppRoot(
                container: MyApp.container,
                plugins: [YourPlugin()],
                manifestLoader: BundledPluginManifestLoader()
            )
        }
    }
}
```

### 4. Enable in plugins.json

```json
{
  "plugins": {
    "your-plugin": {
      "enabled": true,
      "version": "1.0.0",
      "source": "local"
    }
  }
}
```

## Common Mistakes

- Importing anything other than `VBWDCore`
- Forgetting `@unchecked Sendable` on the Plugin class
- Forgetting `nonisolated` on `init()`
- Dashboard component names not starting with `Dashboard`
- Profile component names not starting with `Profile`
- Putting business logic in the Plugin entry point (violates SRP)
- Making views `public` when they're only used internally
- Using `import Combine` when async/await suffices
- Using raw property mutation on store instead of named methods
