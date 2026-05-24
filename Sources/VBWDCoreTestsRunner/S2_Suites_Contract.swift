import Foundation
import VBWDCore
import VBWDCoreTestKit

func registerPluginContractSuites(_ runner: TestRunner) {

    // MARK: P1 — SemanticVersion
    runner.suite("P1 SemanticVersion") { s in
        await s.test("parses_major_minor_patch") {
            let v = try SemanticVersion(parsing: "1.2.3")
            s.expectEqual([v.major, v.minor, v.patch], [1, 2, 3])
        }
        await s.test("invalid_string_throws") {
            for bad in ["1.2", "x", "", "1.2.3.4", "a.b.c"] {
                await s.expectThrows { _ = try SemanticVersion(parsing: bad) }
            }
        }
        await s.test("comparable_ordering") {
            let a = try SemanticVersion(parsing: "1.2.0")
            let b = try SemanticVersion(parsing: "1.10.0")
            let c = try SemanticVersion(parsing: "2.0.0")
            let d = try SemanticVersion(parsing: "1.9.9")
            let e = try SemanticVersion(parsing: "1.2.3")
            s.expect(a < b)
            s.expect(c > d)
            s.expect(e == SemanticVersion(1, 2, 3))
        }
    }

    // MARK: P1 — VersionConstraint (table-driven, web semver parity)
    runner.suite("P1 VersionConstraint") { s in
        func v(_ str: String) -> SemanticVersion { try! SemanticVersion(parsing: str) }
        await s.test("caret_allows_minor_patch_not_major") {
            let c = VersionConstraint("^1.2.0")
            s.expect(c.isSatisfied(by: v("1.2.0")))
            s.expect(c.isSatisfied(by: v("1.9.9")))
            s.expect(!c.isSatisfied(by: v("2.0.0")))
            s.expect(!c.isSatisfied(by: v("1.1.9")))
        }
        await s.test("caret_zero_major_locks_minor") {
            let c = VersionConstraint("^0.2.3")
            s.expect(c.isSatisfied(by: v("0.2.9")))
            s.expect(!c.isSatisfied(by: v("0.3.0")))
        }
        await s.test("tilde_allows_patch_not_minor") {
            let c = VersionConstraint("~1.2.0")
            s.expect(c.isSatisfied(by: v("1.2.9")))
            s.expect(!c.isSatisfied(by: v("1.3.0")))
        }
        await s.test("gte_gt_lte_lt_exact") {
            s.expect(VersionConstraint(">=1.2.3").isSatisfied(by: v("1.2.3")))
            s.expect(!VersionConstraint(">1.2.3").isSatisfied(by: v("1.2.3")))
            s.expect(VersionConstraint("<=2.0.0").isSatisfied(by: v("2.0.0")))
            s.expect(!VersionConstraint("<1.0.0").isSatisfied(by: v("1.0.0")))
            s.expect(VersionConstraint("1.2.3").isSatisfied(by: v("1.2.3")))
            s.expect(!VersionConstraint("1.2.3").isSatisfied(by: v("1.2.4")))
        }
        await s.test("x_range") {
            s.expect(VersionConstraint("1.x").isSatisfied(by: v("1.7.3")))
            s.expect(!VersionConstraint("1.x").isSatisfied(by: v("2.0.0")))
            s.expect(VersionConstraint("1.2.x").isSatisfied(by: v("1.2.9")))
            s.expect(!VersionConstraint("1.2.x").isSatisfied(by: v("1.3.0")))
        }
        await s.test("star_or_empty_matchesAny") {
            s.expect(VersionConstraint("*").isSatisfied(by: v("9.9.9")))
            s.expect(VersionConstraint("").isSatisfied(by: v("0.0.1")))
        }
    }

    // MARK: P2 — Plugin metadata / status
    runner.suite("P2 Plugin metadata & status") { s in
        await s.test("dependencies_list_and_constrained_forms_resolve") {
            let list = PluginDependencies.list(["a", "b"]).resolved
            s.expectEqual(list.map { $0.name }.sorted(), ["a", "b"])
            s.expect(list.allSatisfy { $0.constraint.isSatisfied(by: SemanticVersion(9, 9, 9)) })
            let con = PluginDependencies.constrained(["a": "^1.0.0"]).resolved
            s.expectEqual(con.first?.name, "a")
            s.expect(con.first!.constraint.isSatisfied(by: SemanticVersion(1, 4, 0)))
            s.expect(!con.first!.constraint.isSatisfied(by: SemanticVersion(2, 0, 0)))
        }
        await s.test("default_lifecycle_hooks_are_noop") {
            final class Bare: Plugin, @unchecked Sendable {
                let metadata = PluginMetadata(name: "bare", version: SemanticVersion(1, 0, 0))
            }
            let p = Bare()
            await s.expectNoThrow { try await p.activate() }
            await s.expectNoThrow { try await p.deactivate() }
            await s.expectNoThrow { try await p.uninstall() }
        }
        await s.test("keywords_default_empty_and_status_error_carriesMessage") {
            let m = PluginMetadata(name: "x", version: SemanticVersion(1, 0, 0))
            s.expectEqual(m.keywords, [])
            s.expectEqual(PluginStatus.error("boom"), .error("boom"))
            s.expect(PluginStatus.active != PluginStatus.inactive)
        }
    }

    // MARK: P3 — PluginManifest + loaders
    runner.suite("P3 PluginManifest") { s in
        await s.test("decodes_manifest_fixture_liveShape") {
            let m = try JSONDecoder().decode(
                PluginManifest.self, from: loadFixture("plugins_manifest.json"))
            s.expect(m.plugins["booking"]?.enabled == true)
            s.expectEqual(m.plugins["booking"]?.version, "0.1.0")
            s.expectEqual(m.plugins["booking"]?.source, "local")
        }
        await s.test("entry_missing_installedAt_decodesNil") {
            let json = Data(#"{"plugins":{"p":{"enabled":true,"version":"1.0.0","source":"local"}}}"#.utf8)
            let m = try JSONDecoder().decode(PluginManifest.self, from: json)
            s.expectNil(m.plugins["p"]?.installedAt)
        }
        await s.test("enabledNames_returnsOnlyEnabled") {
            let m = try JSONDecoder().decode(
                PluginManifest.self, from: loadFixture("plugins_manifest.json"))
            s.expect(m.enabledNames.contains("example"))
            s.expect(!m.enabledNames.contains("disabledsample"))
            s.expect(!m.isEnabled("disabledsample"))
        }
    }

    runner.suite("P3 ManifestLoader contract (Liskov)") { s in
        let fixture = try! JSONDecoder().decode(
            PluginManifest.self, from: loadFixture("plugins_manifest.json"))

        await s.test("remote_loader_returnsBackendManifest") {
            let spy = SpyAPIClient { path, _, _ in
                path == "/plugins" ? (200, (try? loadFixture("plugins_manifest.json")) ?? Data())
                                   : (404, Data())
            }
            let loader = RemotePluginManifestLoader(api: spy, path: "/plugins")
            let m = await loader.load()
            s.expect(m.plugins["example"]?.enabled == true)
        }
        await s.test("remote_failure_fallsBackToBundled_noThrow") {
            let spy = SpyAPIClient { _, _, _ in (500, Data()) }
            let loader = RemotePluginManifestLoader(api: spy, path: "/plugins",
                                                    fallback: fixture)
            let m = await loader.load()
            s.expect(m.plugins["booking"] != nil)   // fell back, did not throw
        }
        await s.test("inMemory_loader_returnsConfiguredManifest") {
            let m = await InMemoryPluginManifestLoader(fixture).load()
            s.expectEqual(m.enabledNames.contains("example"), true)
        }
    }
}
