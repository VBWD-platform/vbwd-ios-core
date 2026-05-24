import SwiftUI
import Combine
import VBWDCore

// Reference plugin (Sprint 02 / 2.6). Depends ONLY on the public `VBWDCore`
// module — proof a third-party plugin needs nothing internal and the core is
// open for extension, closed for modification (OCP). Modelled on the web
// `vbwd-fe-user/plugins/booking` plugin.

/// A plugin-owned store (web Pinia store analogue).
@MainActor
public final class ExampleStore: ObservableObject {
    @Published public var active = false
    @Published public var sawLogin = false
    @Published public var count = 0
    
    nonisolated public init() {}
}

public final class ExamplePlugin: Plugin, @unchecked Sendable {
    public let store = ExampleStore()
    private let unsubscribeBox = UnsubscribeBox()

    nonisolated public init() {}

    public var metadata: PluginMetadata {
        PluginMetadata(
            name: "example",
            version: SemanticVersion(1, 0, 0),
            description: "Reference plugin exercising every PlatformSDK seam.",
            author: "VBWD",
            keywords: ["example", "reference"],
            dependencies: .none,
            translations: ["en": ["example.title": "Example"]]
        )
    }

    public func install(_ sdk: PlatformSDK) async throws {
        // 1. Routes — public + auth/permission-gated (web addRoute parity)
        try sdk.addRoute(PluginRoute(
            path: "/example", name: "example",
            view: { AnyView(ExampleScreen()) }))
        try sdk.addRoute(PluginRoute(
            path: "/example/secret", name: "example-secret",
            requiresAuth: true,
            requiredUserPermission: "user.profile.view",
            view: { AnyView(Text("secret")) }))

        // 2. Dashboard widget (web `Dashboard*` convention)
        sdk.addComponent("DashboardExample") { AnyView(ExampleWidget()) }

        // 3. Store
        try sdk.createStore("exampleStore", store)

        // 4. Translations (merged into the app i18n)
        sdk.addTranslations("en", ["example.title": "Example"])
        sdk.addTranslations("de", ["example.title": "Beispiel"])

        // 5. Event subscription (decoupled core ↔ plugin via the bus)
        unsubscribeBox.unsubscribe = sdk.events.on(AppEvents.authLogin) { [weak store] _ in
            Task { @MainActor in
                store?.sawLogin = true
            }
        }

        // 6. Sample backend read via the shared client (tolerated if absent)
        let _: EmptyResponse? = try? await sdk.api.get("/tarif-plans/")
        
        // 7. Menu items (Sprint 03)
        sdk.addMenuItem(MenuItem(
            id: "example-home",
            icon: "star.fill",
            title: "Example Home",
            routePath: "/example",
            order: 50
        ))
        
        sdk.addMenuItem(MenuItem(
            id: "example-secret",
            icon: "lock.fill",
            title: "Secret Feature",
            badge: "PRO",
            routePath: "/example/secret",
            requiredPermission: "user.profile.view",
            order: 51
        ))
        
        sdk.addMenuItem(MenuItem(
            id: "example-counter",
            icon: "number.circle.fill",
            title: "Counter Demo",
            badge: await MainActor.run { store.count > 0 ? "\(store.count)" : nil },
            action: { [weak store] in
                Task { @MainActor in
                    store?.count += 1
                }
            },
            order: 52
        ))
    }

    public func activate() async throws {
        await MainActor.run {
            store.active = true
        }
    }
    
    public func deactivate() async throws {
        await MainActor.run {
            store.active = false
        }
    }
    
    public func uninstall() async throws {
        unsubscribeBox.unsubscribe?()
        await MainActor.run {
            store.active = false
        }
    }
}

// Helper to work around Sendable conformance
private final class UnsubscribeBox: @unchecked Sendable {
    var unsubscribe: Unsubscribe?
}

struct ExampleScreen: View {
    var body: some View { Text("Example plugin screen").padding() }
}

struct ExampleWidget: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Example Widget").font(.headline)
            Text("Contributed by the example plugin")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(16)
    }
}
