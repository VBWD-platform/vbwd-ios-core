import Foundation
import SwiftUI
import VBWDCore
import VBWDCoreTestKit

func registerPlatformSDKSuites(_ runner: TestRunner) {

    func route(_ path: String, _ name: String) -> PluginRoute {
        PluginRoute(path: path, name: name, view: anyText(name))
    }

    // MARK: P4 — RouteRegistry
    runner.suite("P4 RouteRegistry") { s in
        await s.test("add_thenAll_returnsRoute") {
            let r = RouteRegistry()
            try r.add(route("/a", "a"))
            s.expectEqual(r.all().count, 1)
            s.expectEqual(r.all().first?.path, "/a")
        }
        await s.test("duplicate_path_isRejected") {
            let r = RouteRegistry()
            try r.add(route("/a", "a"))
            await s.expectThrows { try r.add(route("/a", "b")) }
        }
        await s.test("duplicate_name_isRejected") {
            let r = RouteRegistry()
            try r.add(route("/a", "a"))
            await s.expectThrows { try r.add(route("/b", "a")) }
        }
    }

    // MARK: P4 — ComponentRegistry
    runner.suite("P4 ComponentRegistry") { s in
        await s.test("add_get_roundTrips") {
            let c = ComponentRegistry()
            c.add("X", anyText("X"))
            s.expectNotNil(c.get("X"))
        }
        await s.test("remove_deletes") {
            let c = ComponentRegistry()
            c.add("X", anyText("X")); c.remove("X")
            s.expectNil(c.get("X"))
        }
        await s.test("all_returnsEveryRegistered") {
            let c = ComponentRegistry()
            c.add("A", anyText("A")); c.add("B", anyText("B"))
            s.expectEqual(Set(c.all().keys), ["A", "B"])
        }
        await s.test("dashboardPrefix_filterable_inOrder") {
            let c = ComponentRegistry()
            c.add("Other", anyText("o"))
            c.add("DashboardOne", anyText("1"))
            c.add("DashboardTwo", anyText("2"))
            s.expectEqual(c.dashboardComponents().map { $0.name },
                          ["DashboardOne", "DashboardTwo"])
        }
    }

    // MARK: P4 — StoreRegistry
    runner.suite("P4 StoreRegistry") { s in
        await s.test("create_thenGet_returnsSameInstance") {
            let reg = StoreRegistry()
            let store = CounterStore()
            try reg.create("counter", store)
            s.expect((reg.get("counter") as AnyObject?) === store)
        }
        await s.test("duplicate_id_isRejected") {
            let reg = StoreRegistry()
            try reg.create("c", CounterStore())
            await s.expectThrows { try reg.create("c", CounterStore()) }
        }
    }

    // MARK: P4 — LocalizationRegistry
    runner.suite("P4 LocalizationRegistry") { s in
        await s.test("add_twoLocales_bothPresent") {
            let l = LocalizationRegistry()
            l.add("en", ["hi": "Hi"]); l.add("de", ["hi": "Hallo"])
            s.expectEqual(l.t("hi", locale: "en"), "Hi")
            s.expectEqual(l.t("hi", locale: "de"), "Hallo")
        }
        await s.test("merge_sameLocale_keysUnion_lastWins") {
            let l = LocalizationRegistry()
            l.add("en", ["a": "1", "b": "2"])
            l.add("en", ["b": "9", "c": "3"])
            s.expectEqual(l.t("a", locale: "en"), "1")
            s.expectEqual(l.t("b", locale: "en"), "9")
            s.expectEqual(l.t("c", locale: "en"), "3")
        }
        await s.test("t_returnsKeyItself_whenMissing") {
            s.expectEqual(LocalizationRegistry().t("missing", locale: "en"), "missing")
        }
    }

    // MARK: P5 — DefaultPlatformSDK facade
    runner.suite("P5 DefaultPlatformSDK") { s in
        await s.test("addRoute_isVisibleVia_getRoutes") { @MainActor in
            let sdk = makeSDK()
            try sdk.addRoute(route("/x", "x"))
            s.expectEqual(sdk.getRoutes().first?.name, "x")
        }
        await s.test("addComponent_removeComponent_getComponents") { @MainActor in
            let sdk = makeSDK()
            sdk.addComponent("C", anyText("C"))
            s.expect(sdk.getComponents()["C"] != nil)
            sdk.removeComponent("C")
            s.expect(sdk.getComponents()["C"] == nil)
        }
        await s.test("createStore_getStores") { @MainActor in
            let sdk = makeSDK()
            let st = CounterStore()
            try sdk.createStore("s", st)
            s.expect((sdk.getStores()["s"] as AnyObject?) === st)
        }
        await s.test("addTranslations_getTranslations_merged") { @MainActor in
            let sdk = makeSDK()
            sdk.addTranslations("en", ["k": "v"])
            s.expectEqual(sdk.getTranslations()["en"]?["k"], "v")
        }
        await s.test("exposes_injected_api_and_events") { @MainActor in
            let api = SpyAPIClient()
            let sdk = makeSDK(api)
            s.expect((sdk.api as AnyObject) === api)
            s.expectNotNil(sdk.events)
        }
        await s.test("delegates_to_registries_notReimplemented") { @MainActor in
            let sdk = makeSDK()
            try sdk.addRoute(route("/d", "d"))
            // facade route list and registry are the same source
            s.expectEqual(sdk.getRoutes().count, sdk.routes.all().count)
        }
    }
}
