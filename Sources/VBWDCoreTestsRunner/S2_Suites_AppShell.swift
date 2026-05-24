import Foundation
import SwiftUI
import VBWDCore
import VBWDCoreTestKit

func registerAppShellSuites(_ runner: TestRunner) {

    func route(_ path: String, _ name: String,
               auth: Bool = false, perm: String? = nil) -> PluginRoute {
        PluginRoute(path: path, name: name, requiresAuth: auth,
                    requiredUserPermission: perm, view: anyText(name))
    }

    // MARK: P8 — Navigator (router guard parity)
    runner.suite("P8 Navigator") { s in
        await s.test("unknownPath_returnsNotFound") {
            s.expectEqual(Navigator.resolve(path: "/nope", routes: [],
                isAuthenticated: true, userPermissions: []), .notFound)
        }
        await s.test("publicRoute_allowsWhenSignedOut") {
            s.expectEqual(Navigator.resolve(path: "/p",
                routes: [route("/p", "p")],
                isAuthenticated: false, userPermissions: []), .allow)
        }
        await s.test("requiresAuth_andSignedOut_redirectsToLogin") {
            s.expectEqual(Navigator.resolve(path: "/s",
                routes: [route("/s", "s", auth: true)],
                isAuthenticated: false, userPermissions: []), .redirectToLogin)
        }
        await s.test("requiresAuth_andAuthed_allows") {
            s.expectEqual(Navigator.resolve(path: "/s",
                routes: [route("/s", "s", auth: true)],
                isAuthenticated: true, userPermissions: []), .allow)
        }
        await s.test("requiredPermission_missing_returnsForbidden") {
            s.expectEqual(Navigator.resolve(path: "/x",
                routes: [route("/x", "x", auth: true, perm: "user.profile.view")],
                isAuthenticated: true, userPermissions: []), .forbidden)
        }
        await s.test("requiredPermission_present_allows") {
            s.expectEqual(Navigator.resolve(path: "/x",
                routes: [route("/x", "x", auth: true, perm: "user.profile.view")],
                isAuthenticated: true,
                userPermissions: ["user.profile.view"]), .allow)
        }
        await s.test("wildcardPermission_satisfies_reusesEvaluator") {
            s.expectEqual(Navigator.resolve(path: "/x",
                routes: [route("/x", "x", auth: true, perm: "subscription.tokens.view")],
                isAuthenticated: true,
                userPermissions: ["subscription.*"]), .allow)
        }
        await s.test("coreRoute_takesPrecedence_overPluginSamePath") {
            // core first, plugin second, same path → first (core) wins
            let routes = [route("/dup", "core"), route("/dup", "plugin", auth: true)]
            // core is public → allow even when signed out (plugin would redirect)
            s.expectEqual(Navigator.resolve(path: "/dup", routes: routes,
                isAuthenticated: false, userPermissions: []), .allow)
        }
    }

    // MARK: P9 — Dashboard widget injection
    runner.suite("P9 Dashboard widget injection") { s in
        await s.test("noRegistry_showsNoPluginWidgets_sprint01Regression") { @MainActor in
            let vm = DashboardViewModel(user: Fixtures.user(), api: SpyAPIClient())
            s.expect(vm.pluginWidgets.isEmpty)
        }
        await s.test("dashboardPrefixed_surfaced_others_not_inOrder") { @MainActor in
            let reg = ComponentRegistry()
            reg.add("Other", anyText("o"))
            reg.add("DashboardA", anyText("a"))
            reg.add("DashboardB", anyText("b"))
            let vm = DashboardViewModel(user: Fixtures.user(), api: SpyAPIClient(),
                                        components: reg)
            s.expectEqual(vm.pluginWidgets.map { $0.name }, ["DashboardA", "DashboardB"])
        }
        await s.test("absentComponent_meansAbsentWidget") { @MainActor in
            let reg = ComponentRegistry()              // nothing added
            let vm = DashboardViewModel(user: Fixtures.user(), api: SpyAPIClient(),
                                        components: reg)
            s.expect(vm.pluginWidgets.isEmpty)
        }
    }

    // MARK: P10 — Localization application
    runner.suite("P10 Localization") { s in
        await s.test("pluginTranslations_resolvedVia_t") { @MainActor in
            let reg = LocalizationRegistry()
            reg.add("en", ["greet": "Hello"])
            let loc = Localization(registry: reg, locale: "en")
            s.expectEqual(loc.t("greet"), "Hello")
        }
        await s.test("missingKey_returnsKey") { @MainActor in
            let loc = Localization(registry: LocalizationRegistry())
            s.expectEqual(loc.t("absent"), "absent")
        }
        await s.test("coreLocale_overridable_byPlugin_lastWins") { @MainActor in
            let reg = LocalizationRegistry()
            reg.add("en", ["k": "core"])
            reg.add("en", ["k": "plugin"])
            s.expectEqual(Localization(registry: reg).t("k"), "plugin")
        }
        await s.test("localeSwitch_resolvesCorrectBundle") { @MainActor in
            let reg = LocalizationRegistry()
            reg.add("en", ["hi": "Hi"]); reg.add("de", ["hi": "Hallo"])
            let loc = Localization(registry: reg, locale: "en")
            s.expectEqual(loc.t("hi"), "Hi")
            loc.locale = "de"
            s.expectEqual(loc.t("hi"), "Hallo")
        }
    }
}
