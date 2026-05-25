# vbwd-ios-core

Core SDK for the **VBWD iOS platform** — provides authentication, networking, plugin system, theming, and all shared UI screens.

## Architecture

```
Sources/VBWDCore/
├── Composition/         ← DI root (SDKContainer), plugin host
├── Domain/              ← Business logic: auth, profile, cart, billing, permissions
├── Networking/          ← Protocol-based HTTP client (APIClient → URLSessionAPIClient)
├── Persistence/         ← Token storage (Keychain)
├── Session/             ← Auth state machine (AuthSession, AuthState)
├── Plugins/             ← Plugin contracts, registries, theme system, side menu
│   ├── Registries/      ← Route, Component, Store, Localization, CheckoutSource
│   └── Theme/           ← AppTheme protocol + built-in themes
├── Events/              ← Pub/sub event bus
└── UI/                  ← SwiftUI views + view models
    ├── AppShell/        ← Root view, navigation, menu toolbar, settings
    ├── Login/           ← Login form
    ├── Dashboard/       ← Widget grid (invoices, tokens, subscriptions)
    ├── Profile/         ← Profile edit
    ├── Store/           ← Token store, buy tokens
    ├── Checkout/        ← Checkout flow, payment method selection, confirmation
    └── Billing/         ← Invoice list + detail with PDF download
```

### Key Patterns

- **SOLID** — protocols at every boundary (`APIClient`, `TokenStore`, `AuthService`, `PlatformSDK`)
- **Dependency injection** — `SDKContainer` is the only place concrete types are named
- **Plugin architecture** — mirrors the web `vbwd-fe-core` plugin system
- **Web parity** — UI screens port their web Vue counterparts faithfully
- **Swift 6** — strict concurrency, `@MainActor` on UI, `Sendable` types

## Targets

| Target | Type | Purpose |
|---|---|---|
| `VBWDCore` | Library | Main SDK — import this in your app and plugins |
| `VBWDCoreTestKit` | Library | Dependency-free test harness (no XCTest) |
| `VBWDCoreTestsRunner` | Executable | Runs all unit tests via `swift run VBWDCoreTestsRunner` |

## Quick Start

### 1. Add as a local package

```bash
cd your-app/Packages
git submodule add https://github.com/VBWD-platform/vbwd-ios-core.git
```

### 2. Import in Xcode

1. Open your `.xcodeproj`
2. Add local package: `Packages/vbwd-ios-core`
3. Add `VBWDCore` framework to your app target

### 3. Bootstrap in your app

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
                plugins: [],    // add your plugins here
                manifestLoader: BundledPluginManifestLoader()
            )
        }
    }
}
```

## Plugin System

Plugins extend the app through `PlatformSDK` seams:

| SDK Method | What it does |
|---|---|
| `sdk.addRoute()` | Register a screen at a path |
| `sdk.addMenuItem()` | Add item to side menu |
| `sdk.addComponent()` | Register a pluggable UI component |
| `sdk.createStore()` | Create an observable plugin store |
| `sdk.addTranslations()` | Add localized strings |
| `sdk.addPaymentAction()` | Register a payment method handler |
| `sdk.cart` | Shared shopping cart |
| `sdk.checkoutSources` | Checkout source registry |
| `sdk.events` | Event bus (pub/sub) |
| `sdk.api` | Authenticated HTTP client |

See [docs/human/PLUGIN-DEVELOPMENT.md](docs/human/PLUGIN-DEVELOPMENT.md) for the full plugin authoring guide.

## Testing

```bash
# Run all unit tests (569 assertions)
swift run VBWDCoreTestsRunner

# Run XCUITests in Xcode
# Scheme: VBWD → Test target: VBWDUITests
```

Test suites are organized by sprint:

| Suite | Coverage |
|---|---|
| `Suites_Networking` | APIClient, HTTP methods, error handling |
| `Suites_Persistence` | TokenStore, Keychain |
| `Suites_Domain` | Auth, profile, store services |
| `Suites_SessionUI` | AuthSession state machine |
| `Suites_Composition` | SDKContainer, DI wiring |
| `S2_Suites_*` | Plugin system, registries |
| `S4_Suites_Profile` | Profile edit |
| `S5_Suites_Theme` | Theme switching |
| `S6_Suites_StoreAndBilling` | Token store, invoices |
| `S6b_Suites_Checkout` | Checkout flow |
| `S6c_Suites_Cart` | Cart, checkout sources |
| `S6d_Suites_InvoiceDetail` | Invoice detail, PDF download |

## Requirements

- Swift 6.0+ / Xcode 16+
- iOS 16+ / macOS 13+
- No external dependencies

## License

BSL 1.1 (Business Source Licence)
