import Foundation
import SwiftUI
import VBWDCore
import ExamplePlugin
import VBWDCoreTestKit

/// The minimal plugin from PLUGIN-GUIDE.md — a *compiled, tested* type so the
/// guide cannot silently drift from the SDK (Clean Code: docs as code).
final class MinimalGuidePlugin: Plugin, @unchecked Sendable {
    var metadata: PluginMetadata {
        PluginMetadata(name: "guide-minimal", version: SemanticVersion(1, 0, 0))
    }
    func install(_ sdk: PlatformSDK) async throws {
        try sdk.addRoute(PluginRoute(path: "/guide", name: "guide",
                                     view: { AnyView(Text("guide")) }))
        sdk.addComponent("DashboardGuide") { AnyView(Text("w")) }
    }
}

func registerExamplePluginSuites(_ runner: TestRunner) {

    runner.suite("P11 ExamplePlugin") { s in
        await s.test("install_registersRoute_widget_store_translations") { @MainActor in
            let sdk = makeSDK()
            let p = ExamplePlugin()
            try await p.install(sdk)
            s.expect(sdk.getRoutes().contains { $0.path == "/example" })
            s.expect(sdk.getComponents()["DashboardExample"] != nil)
            s.expect(sdk.getStores()["exampleStore"] != nil)
            s.expectEqual(sdk.getTranslations()["en"]?["example.title"], "Example")
            s.expectEqual(sdk.getTranslations()["de"]?["example.title"], "Beispiel")
        }
        await s.test("secretRoute_hasAuthAndPermissionMeta") { @MainActor in
            let sdk = makeSDK()
            try await ExamplePlugin().install(sdk)
            let secret = sdk.getRoutes().first { $0.path == "/example/secret" }
            s.expectNotNil(secret)
            s.expectEqual(secret?.requiresAuth, true)
            s.expectEqual(secret?.requiredUserPermission, "user.profile.view")
        }
        await s.test("activate_setsActive_deactivate_clears") { @MainActor in
            let p = ExamplePlugin()
            try await p.activate()
            s.expect(p.store.active)
            try await p.deactivate()
            s.expect(!p.store.active)
        }
        await s.test("subscribes_toAuthLogin_event") { @MainActor in
            let sdk = makeSDK()
            let p = ExamplePlugin()
            try await p.install(sdk)
            // Yield to let fire-and-forget on() Task register the listener
            try? await Task.sleep(nanoseconds: 50_000_000)
            s.expect(!p.store.sawLogin)
            sdk.events.emit(AppEvents.authLogin, nil)
            // Yield to let fire-and-forget emit() Task invoke callbacks
            try? await Task.sleep(nanoseconds: 50_000_000)
            s.expect(p.store.sawLogin)
        }
        await s.test("dependsOnNothingInternal_onlyPublicSDK") {
            // Compile-time fact: ExamplePlugin is its own target depending only
            // on VBWDCore (see Package.swift). Runtime sanity:
            s.expectEqual(ExamplePlugin().metadata.name, "example")
        }
    }

    // Liskov: the REAL plugin passes the same contract as SpyPlugin (2.4).
    registerPluginContract(runner, "ExamplePlugin") { ExamplePlugin() }

    // The guide's minimal template is a real type and must also pass.
    registerPluginContract(runner, "GuideTemplate") { MinimalGuidePlugin() }
}
