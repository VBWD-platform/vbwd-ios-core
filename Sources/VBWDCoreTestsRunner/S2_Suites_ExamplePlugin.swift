import Foundation
import SwiftUI
import VBWDCore
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

    // RichSpyPlugin exercises the same SDK seams as ExamplePlugin; verify it
    // passes the Liskov contract like any real plugin would.
    registerPluginContract(runner, "RichSpyPlugin") { RichSpyPlugin() }

    // The guide's minimal template is a real type and must also pass.
    registerPluginContract(runner, "GuideTemplate") { MinimalGuidePlugin() }

    // RichSpyPlugin integration tests (formerly ExamplePlugin tests)
    runner.suite("P11 RichSpyPlugin") { s in
        await s.test("install_registersRoute_widget_store_translations") { @MainActor in
            let sdk = makeSDK()
            let p = RichSpyPlugin()
            try await p.install(sdk)
            s.expect(sdk.getRoutes().contains { $0.path == "/rich" })
            s.expect(sdk.getComponents()["DashboardRich"] != nil)
            s.expect(sdk.getStores()["richStore"] != nil)
            s.expectEqual(sdk.getTranslations()["en"]?["rich.title"], "Rich")
            s.expectEqual(sdk.getTranslations()["de"]?["rich.title"], "Reich")
        }
        await s.test("secretRoute_hasAuthAndPermissionMeta") { @MainActor in
            let sdk = makeSDK()
            try await RichSpyPlugin().install(sdk)
            let secret = sdk.getRoutes().first { $0.path == "/rich/secret" }
            s.expectNotNil(secret)
            s.expectEqual(secret?.requiresAuth, true)
            s.expectEqual(secret?.requiredUserPermission, "user.profile.view")
        }
        await s.test("activate_setsActive_deactivate_clears") { @MainActor in
            let p = RichSpyPlugin()
            try await p.activate()
            s.expect(p.active)
            try await p.deactivate()
            s.expect(!p.active)
        }
    }
}
