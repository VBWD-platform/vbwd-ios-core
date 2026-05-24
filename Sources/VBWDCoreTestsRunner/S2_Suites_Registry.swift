import Foundation
import VBWDCore
import VBWDCoreTestKit

func registerPluginRegistrySuites(_ runner: TestRunner) {

    func v(_ s: String) -> SemanticVersion { try! SemanticVersion(parsing: s) }

    // MARK: P7 — register
    runner.suite("P7 PluginRegistry register") { s in
        await s.test("register_setsStatus_registered") { @MainActor in
            let r = PluginRegistry()
            try r.register(SpyPlugin(name: "a"))
            s.expectEqual(r.status(of: "a"), .registered)
        }
        await s.test("register_duplicateName_throws") { @MainActor in
            let r = PluginRegistry()
            try r.register(SpyPlugin(name: "a"))
            await s.expectThrows { try r.register(SpyPlugin(name: "a")) }
        }
        await s.test("all_returnsMetadataWithStatus_inRegistrationOrder") { @MainActor in
            let r = PluginRegistry()
            try r.register(SpyPlugin(name: "a"))
            try r.register(SpyPlugin(name: "b"))
            s.expectEqual(r.all().map { $0.name }, ["a", "b"])
        }
    }

    // MARK: P7 — install / installAll
    runner.suite("P7 PluginRegistry install") { s in
        await s.test("install_callsHook_setsStatus_installed") { @MainActor in
            let r = PluginRegistry()
            let p = SpyPlugin(name: "a")
            try r.register(p)
            try await r.install("a", makeSDK())
            s.expectEqual(r.status(of: "a"), .installed)
            s.expect(p.calls.contains("install"))
        }
        await s.test("installAll_ordersByDependencies_topologically") { @MainActor in
            let r = PluginRegistry()
            // b depends on a → a must install first
            try r.register(SpyPlugin(name: "b", dependencies: .list(["a"])))
            try r.register(SpyPlugin(name: "a"))
            try await r.installAll(makeSDK())
            s.expectEqual(r.status(of: "a"), .installed)
            s.expectEqual(r.status(of: "b"), .installed)
        }
        await s.test("installAll_missingDependency_throws") { @MainActor in
            let r = PluginRegistry()
            try r.register(SpyPlugin(name: "b", dependencies: .list(["missing"])))
            await s.expectThrows { try await r.installAll(makeSDK()) }
        }
        await s.test("installAll_circularDependency_throws") { @MainActor in
            let r = PluginRegistry()
            try r.register(SpyPlugin(name: "a", dependencies: .list(["b"])))
            try r.register(SpyPlugin(name: "b", dependencies: .list(["a"])))
            await s.expectThrows { try await r.installAll(makeSDK()) }
        }
        await s.test("installAll_unsatisfiedVersionConstraint_throws") { @MainActor in
            let r = PluginRegistry()
            try r.register(SpyPlugin(name: "dep", version: v("1.0.0")))
            try r.register(SpyPlugin(name: "x",
                                     dependencies: .constrained(["dep": "^2.0.0"])))
            await s.expectThrows { try await r.installAll(makeSDK()) }
        }
        await s.test("installAll_oneFailingPlugin_isError_othersStillInstalled") { @MainActor in
            let r = PluginRegistry()
            let bad = SpyPlugin(name: "bad"); bad.failInstall = true
            try r.register(bad)
            try r.register(SpyPlugin(name: "good"))
            try await r.installAll(makeSDK())
            if case .error = r.status(of: "bad") { s.expect(true) }
            else { s.expect(false, "bad should be .error") }
            s.expectEqual(r.status(of: "good"), .installed)   // isolation
        }
    }

    // MARK: P7 — activation / guards
    runner.suite("P7 PluginRegistry activation") { s in
        await s.test("activate_requires_installed_or_inactive") { @MainActor in
            let r = PluginRegistry()
            try r.register(SpyPlugin(name: "a"))
            await s.expectThrows { try await r.activate("a") }  // still .registered
        }
        await s.test("activate_then_deactivate_transitions") { @MainActor in
            let r = PluginRegistry()
            let p = SpyPlugin(name: "a")
            try r.register(p)
            try await r.installAll(makeSDK())
            try await r.activate("a")
            s.expectEqual(r.status(of: "a"), .active)
            try await r.deactivate("a")
            s.expectEqual(r.status(of: "a"), .inactive)
            s.expect(p.calls == ["install", "activate", "deactivate"])
        }
        await s.test("deactivate_blocked_whenActiveDependentExists") { @MainActor in
            let r = PluginRegistry()
            try r.register(SpyPlugin(name: "a"))
            try r.register(SpyPlugin(name: "b", dependencies: .list(["a"])))
            try await r.installAll(makeSDK())
            try await r.activate("a")
            try await r.activate("b")
            await s.expectThrows { try await r.deactivate("a") } // b depends on a
        }
        await s.test("uninstall_resetsTo_registered") { @MainActor in
            let r = PluginRegistry()
            let p = SpyPlugin(name: "a")
            try r.register(p)
            try await r.installAll(makeSDK())
            try await r.uninstall("a")
            s.expectEqual(r.status(of: "a"), .registered)
            s.expect(p.calls.contains("uninstall"))
        }
    }

    // MARK: P7 — manifest gate
    runner.suite("P7 PluginRegistry manifest gate") { s in
        await s.test("installAll_skips_pluginsDisabledInManifest") { @MainActor in
            let r = PluginRegistry()
            try r.register(SpyPlugin(name: "on"))
            try r.register(SpyPlugin(name: "off"))
            try await r.installAll(makeSDK(), enabled: ["on"])
            s.expectEqual(r.status(of: "on"), .installed)
            s.expectEqual(r.status(of: "off"), .registered)   // gated out
        }
    }

    // MARK: P7 — Liskov contract (SpyPlugin; ExamplePlugin added in 2.6)
    registerPluginContract(runner, "SpyPlugin") { SpyPlugin(name: "contractSpy") }
}
