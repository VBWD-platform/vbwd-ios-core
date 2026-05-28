import Foundation
import SwiftUI
import VBWDCore
import VBWDCoreTestKit

/// A trivial store object plugins might register.
final class CounterStore: ObservableObject, @unchecked Sendable { @Published var count = 0 }

/// Builds a `DefaultPlatformSDK` wired with spies for tests.
@MainActor
func makeSDK(_ api: SpyAPIClient = SpyAPIClient()) -> DefaultPlatformSDK {
    DefaultPlatformSDK(api: api,
                       apiConfig: APIClientConfig(baseURL: SDKContainer.defaultBaseURL),
                       events: DefaultEventBus(api: api),
                       cart: Cart(), checkoutSources: CheckoutSourceRegistry())
}

func anyText(_ s: String) -> () -> AnyView { { AnyView(Text(s)) } }

/// Scriptable `Plugin` double — records hook order, can fail a hook.
final class SpyPlugin: Plugin, @unchecked Sendable {
    let metadata: PluginMetadata
    private(set) var calls: [String] = []
    var failInstall = false
    var failActivate = false

    init(name: String,
         version: SemanticVersion = SemanticVersion(1, 0, 0),
         dependencies: PluginDependencies = .none) {
        metadata = PluginMetadata(name: name, version: version,
                                  dependencies: dependencies)
    }

    func install(_ sdk: PlatformSDK) async throws {
        calls.append("install")
        if failInstall {
            throw PluginError.installFailed(plugin: metadata.name, message: "spy fail")
        }
    }
    func activate() async throws {
        calls.append("activate")
        if failActivate {
            throw PluginError.invalidState(plugin: metadata.name, message: "spy fail")
        }
    }
    func deactivate() async throws { calls.append("deactivate") }
    func uninstall() async throws { calls.append("uninstall") }
}

/// A plugin test double that registers routes, widgets, translations —
/// exercises every PlatformSDK seam, so PluginHost integration tests can
/// run without importing the real ExamplePlugin package.
final class RichSpyPlugin: Plugin, @unchecked Sendable {
    let metadata = PluginMetadata(
        name: "rich-spy",
        version: SemanticVersion(1, 0, 0),
        description: "Test double exercising all SDK seams.",
        translations: ["en": ["rich.title": "Rich"]]
    )
    private(set) var active = false

    func install(_ sdk: PlatformSDK) async throws {
        try sdk.addRoute(PluginRoute(
            path: "/rich", name: "rich",
            view: { AnyView(Text("rich")) }))
        try sdk.addRoute(PluginRoute(
            path: "/rich/secret", name: "rich-secret",
            requiresAuth: true,
            requiredUserPermission: "user.profile.view",
            view: { AnyView(Text("secret")) }))
        sdk.addComponent("DashboardRich") { AnyView(Text("Rich Widget")) }
        try sdk.createStore("richStore", CounterStore())
        sdk.addTranslations("en", ["rich.title": "Rich"])
        sdk.addTranslations("de", ["rich.title": "Reich"])
    }
    func activate() async throws { active = true }
    func deactivate() async throws { active = false }
    func uninstall() async throws { active = false }
}

/// Reusable Liskov suite: any `Plugin` must observe the install→activate→
/// deactivate sequence and expose metadata. Called for `SpyPlugin` (2.4)
/// and `RichSpyPlugin` — same contract.
func registerPluginContract(_ runner: TestRunner, _ label: String,
                            _ make: @Sendable @escaping () -> Plugin) {
    runner.suite("PluginContract: \(label)") { s in
        await s.test("metadata_nameAndVersion_present") {
            let p = make()
            s.expect(!p.metadata.name.isEmpty)
            s.expect(p.metadata.version >= SemanticVersion(0, 0, 1))
        }
        await s.test("install_activate_deactivate_sequenceObserved") { @MainActor in
            let reg = PluginRegistry()
            let p = make()
            try reg.register(p)
            try await reg.installAll(makeSDK())
            s.expectEqual(reg.status(of: p.metadata.name), .installed)
            try await reg.activate(p.metadata.name)
            s.expectEqual(reg.status(of: p.metadata.name), .active)
            try await reg.deactivate(p.metadata.name)
            s.expectEqual(reg.status(of: p.metadata.name), .inactive)
        }
    }
}
