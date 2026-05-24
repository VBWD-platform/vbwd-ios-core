# Getting Started with VBWDCore

This guide walks you through setting up a new iOS app on top of the VBWDCore SDK.

## Prerequisites

- Xcode 16+ with Swift 6.0
- iOS 16+ deployment target
- A running VBWD backend (or mock for offline development)

## 1. Create a New Xcode Project

Create a standard SwiftUI iOS app in Xcode (File > New > Project > iOS > App).

## 2. Add VBWDCore as a Dependency

### Option A: Git Submodule (recommended for the VBWD monorepo)

```bash
cd YourApp/Packages
git submodule add https://github.com/VBWD-platform/vbwd-ios-core.git
```

Then in Xcode: File > Add Package Dependencies > Add Local > select `Packages/vbwd-ios-core`.

### Option B: Swift Package Manager (remote)

In Xcode: File > Add Package Dependencies, enter:

```
https://github.com/VBWD-platform/vbwd-ios-core.git
```

Select the `VBWDCore` library product and add it to your app target.

## 3. Minimal App Setup

Replace your `App` entry point:

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

This gives you:
- Login screen with email/password authentication
- Dashboard with user profile card
- Side menu (burger menu) with navigation
- Profile editing screen
- Settings screen with theme switcher
- Keychain-backed session persistence

## 4. Add a Plugin Config File

Create `plugins.json` in your app target (ensure it's added to "Copy Bundle Resources"):

```json
{
  "plugins": {}
}
```

This file controls which plugins are enabled. See [Plugin Development](PLUGIN-DEVELOPMENT.md) for details.

## 5. Configure the Backend URL

By default, VBWDCore connects to `https://vbwd.cc/api/v1`. To use a different backend:

```swift
@MainActor private static let container = SDKContainer(
    baseURL: URL(string: "https://your-backend.example.com/api/v1")!
)
```

## 6. Build and Run

Build for iOS Simulator. You should see the login screen. Enter valid credentials to authenticate against your backend.

---

## What You Get Out of the Box

### Authentication
- Login/logout with JWT tokens
- Keychain-backed token persistence
- Automatic session restoration on app launch
- Token refresh support (endpoint configurable)

### Dashboard
- User profile card (always visible)
- Token balance card (requires `subscription.tokens.view` permission)
- Invoice list card (requires `subscription.invoices.view` permission)
- Plugin widget grid (2-column layout, auto-discovered)

### Navigation
- Burger menu with core items (Dashboard, Profile, Settings)
- Plugin-contributed menu items (auto-sorted by `order`)
- Permission-gated routes

### Profile
- Read-only account info (email, role)
- Editable personal details (name, company, phone, address)
- Change password form with validation
- Plugin-contributed profile sections

### Settings
- Theme switcher (Classic, Dark Blue, Dark Green)
- Persisted theme selection via UserDefaults

### Event Bus
- App-wide decoupled event system
- Backend forwarding with retry for non-local events
- 40+ predefined event names (auth, subscription, payment, plugin lifecycle)

---

## Next Steps

- [Architecture](ARCHITECTURE.md) — understand the layered design
- [Plugin Development](PLUGIN-DEVELOPMENT.md) — build your first plugin
- [API Reference](API-REFERENCE.md) — full type and method reference
