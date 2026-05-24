import Foundation
import VBWDCore
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
                manifestLoader: loader(manifest(["rich-spy": true,
                                                 "disabledsample": false])),
                plugins: [RichSpyPlugin(), disabled])
            await host.bootstrap()
            s.expectEqual(host.status(of: "rich-spy"), .active)
            s.expectEqual(host.status(of: "disabledsample"), .registered) // gated
            s.expect(disabled.calls.isEmpty)
        }
        await s.test("bootstrap_injectsPluginRoutes") { @MainActor in
            let host = PluginHost(
                api: SpyAPIClient(),
                manifestLoader: loader(manifest(["rich-spy": true])),
                plugins: [RichSpyPlugin()])
            await host.bootstrap()
            s.expect(host.routes.contains { $0.path == "/rich" })
        }
        await s.test("bootstrap_providesPopulatedSDK_withWidget") { @MainActor in
            let host = PluginHost(
                api: SpyAPIClient(),
                manifestLoader: loader(manifest(["rich-spy": true])),
                plugins: [RichSpyPlugin()])
            await host.bootstrap()
            s.expect(host.components.get("DashboardRich") != nil)
            s.expect(host.sdk.getTranslations()["en"]?["rich.title"] == "Rich")
        }
        await s.test("bootstrap_isErrorIsolated_oneBadPlugin_doesNotBlockShell") { @MainActor in
            let bad = SpyPlugin(name: "badone"); bad.failInstall = true
            let host = PluginHost(
                api: SpyAPIClient(),
                manifestLoader: loader(manifest(["rich-spy": true, "badone": true])),
                plugins: [RichSpyPlugin(), bad])
            await host.bootstrap()
            if case .error = host.status(of: "badone") { s.expect(true) }
            else { s.expect(false, "badone should be .error") }
            s.expectEqual(host.status(of: "rich-spy"), .active)        // unaffected
            s.expect(host.routes.contains { $0.path == "/rich" })      // shell intact
        }
        await s.test("disabledPlugin_absentFrom_routesAndWidgets") { @MainActor in
            let host = PluginHost(
                api: SpyAPIClient(),
                manifestLoader: loader(manifest(["rich-spy": false])),
                plugins: [RichSpyPlugin()])
            await host.bootstrap()
            s.expect(!host.routes.contains { $0.path == "/rich" })
            s.expect(host.components.get("DashboardRich") == nil)
        }
        await s.test("container_exposesPluginHost_withDefaultPlugins") { @MainActor in
            let c = SDKContainer(tokenStore: InMemoryTokenStore())
            let host = c.makePluginHost(
                plugins: [RichSpyPlugin()],
                manifestLoader: loader(manifest(["rich-spy": true])))
            await host.bootstrap()
            s.expectEqual(host.status(of: "rich-spy"), .active)
        }
    }

    // MARK: P12 — App shell integration (state-driven)
    runner.suite("P12 AppShell integration") { s in
        @MainActor
        func bootstrappedHost(_ enabled: Bool) async -> PluginHost {
            let host = PluginHost(
                api: SpyAPIClient(),
                manifestLoader: loader(manifest(["rich-spy": enabled])),
                plugins: [RichSpyPlugin()])
            await host.bootstrap()
            return host
        }

        await s.test("navigate_toEnabledPluginRoute_resolves") { @MainActor in
            let host = await bootstrappedHost(true)
            s.expectEqual(
                Navigator.resolve(path: "/rich", routes: host.routes,
                                  isAuthenticated: true, userPermissions: []),
                .allow)
        }
        await s.test("navigate_toDisabledPluginRoute_returnsNotFound") { @MainActor in
            let host = await bootstrappedHost(false)
            s.expectEqual(
                Navigator.resolve(path: "/rich", routes: host.routes,
                                  isAuthenticated: true, userPermissions: []),
                .notFound)
        }
        await s.test("secretRoute_redirectsToLogin_whenSignedOut") { @MainActor in
            let host = await bootstrappedHost(true)
            s.expectEqual(
                Navigator.resolve(path: "/rich/secret", routes: host.routes,
                                  isAuthenticated: false, userPermissions: []),
                .redirectToLogin)
        }
        await s.test("authed_dashboard_hasCoreCards_plus_pluginWidget") { @MainActor in
            let host = await bootstrappedHost(true)
            let vm = DashboardViewModel(
                user: Fixtures.user(permissions: ["subscription.tokens.view"]),
                api: SpyAPIClient(), components: host.components)
            s.expect(vm.showTokenCard)                               // core (Sprint 01)
            s.expect(vm.pluginWidgets.contains { $0.name == "DashboardRich" })
        }
    }
}
