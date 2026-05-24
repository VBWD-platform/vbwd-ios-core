import Foundation
import VBWDCore
import ExamplePlugin
import VBWDCoreTestKit

func registerPluginHostSuites(_ runner: TestRunner) {

    func manifest(_ entries: [String: Bool]) -> PluginManifest {
        PluginManifest(plugins: entries.mapValues {
            PluginManifest.Entry(enabled: $0, version: "1.0.0")
        })
    }
    func loader(_ m: PluginManifest) -> PluginManifestLoader {
        InMemoryPluginManifestLoader(m)
    }

    // MARK: P12 — PluginHost bootstrap
    runner.suite("P12 PluginHost") { s in
        await s.test("bootstrap_installsAndActivates_onlyEnabled") { @MainActor in
            let disabled = SpyPlugin(name: "disabledsample")
            let host = PluginHost(
                api: SpyAPIClient(),
                manifestLoader: loader(manifest(["example": true,
                                                 "disabledsample": false])),
                plugins: [ExamplePlugin(), disabled])
            await host.bootstrap()
            s.expectEqual(host.status(of: "example"), .active)
            s.expectEqual(host.status(of: "disabledsample"), .registered) // gated
            s.expect(disabled.calls.isEmpty)
        }
        await s.test("bootstrap_injectsPluginRoutes") { @MainActor in
            let host = PluginHost(
                api: SpyAPIClient(),
                manifestLoader: loader(manifest(["example": true])),
                plugins: [ExamplePlugin()])
            await host.bootstrap()
            s.expect(host.routes.contains { $0.path == "/example" })
        }
        await s.test("bootstrap_providesPopulatedSDK_withWidget") { @MainActor in
            let host = PluginHost(
                api: SpyAPIClient(),
                manifestLoader: loader(manifest(["example": true])),
                plugins: [ExamplePlugin()])
            await host.bootstrap()
            s.expect(host.components.get("DashboardExample") != nil)
            s.expect(host.sdk.getTranslations()["en"]?["example.title"] == "Example")
        }
        await s.test("bootstrap_isErrorIsolated_oneBadPlugin_doesNotBlockShell") { @MainActor in
            let bad = SpyPlugin(name: "badone"); bad.failInstall = true
            let host = PluginHost(
                api: SpyAPIClient(),
                manifestLoader: loader(manifest(["example": true, "badone": true])),
                plugins: [ExamplePlugin(), bad])
            await host.bootstrap()
            if case .error = host.status(of: "badone") { s.expect(true) }
            else { s.expect(false, "badone should be .error") }
            s.expectEqual(host.status(of: "example"), .active)        // unaffected
            s.expect(host.routes.contains { $0.path == "/example" })  // shell intact
        }
        await s.test("disabledPlugin_absentFrom_routesAndWidgets") { @MainActor in
            let host = PluginHost(
                api: SpyAPIClient(),
                manifestLoader: loader(manifest(["example": false])),
                plugins: [ExamplePlugin()])
            await host.bootstrap()
            s.expect(!host.routes.contains { $0.path == "/example" })
            s.expect(host.components.get("DashboardExample") == nil)
        }
        await s.test("container_exposesPluginHost_withDefaultPlugins") { @MainActor in
            let c = SDKContainer(tokenStore: InMemoryTokenStore())
            let host = c.makePluginHost(
                plugins: [ExamplePlugin()],
                manifestLoader: loader(manifest(["example": true])))
            await host.bootstrap()
            s.expectEqual(host.status(of: "example"), .active)
        }
    }

    // MARK: P12 — App shell integration (state-driven)
    runner.suite("P12 AppShell integration") { s in
        @MainActor
        func bootstrappedHost(_ enabled: Bool) async -> PluginHost {
            let host = PluginHost(
                api: SpyAPIClient(),
                manifestLoader: loader(manifest(["example": enabled])),
                plugins: [ExamplePlugin()])
            await host.bootstrap()
            return host
        }

        await s.test("navigate_toEnabledPluginRoute_resolves") { @MainActor in
            let host = await bootstrappedHost(true)
            s.expectEqual(
                Navigator.resolve(path: "/example", routes: host.routes,
                                  isAuthenticated: true, userPermissions: []),
                .allow)
        }
        await s.test("navigate_toDisabledPluginRoute_returnsNotFound") { @MainActor in
            let host = await bootstrappedHost(false)
            s.expectEqual(
                Navigator.resolve(path: "/example", routes: host.routes,
                                  isAuthenticated: true, userPermissions: []),
                .notFound)
        }
        await s.test("secretRoute_redirectsToLogin_whenSignedOut") { @MainActor in
            let host = await bootstrappedHost(true)
            s.expectEqual(
                Navigator.resolve(path: "/example/secret", routes: host.routes,
                                  isAuthenticated: false, userPermissions: []),
                .redirectToLogin)
        }
        await s.test("authed_dashboard_hasCoreCards_plus_pluginWidget") { @MainActor in
            let host = await bootstrappedHost(true)
            let vm = DashboardViewModel(
                user: Fixtures.user(permissions: ["subscription.tokens.view"]),
                api: SpyAPIClient(), components: host.components)
            s.expect(vm.showTokenCard)                               // core (Sprint 01)
            s.expect(vm.pluginWidgets.contains { $0.name == "DashboardExample" })
        }
    }
}
