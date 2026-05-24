import Foundation
import SwiftUI
import VBWDCore
import VBWDCoreTestKit

// MARK: - ThemeRegistry Tests

func registerThemeRegistrySuites(_ runner: TestRunner) {
    runner.suite("ThemeRegistry (5.0)") { s in

        await s.test("test_registry_startsWithThreeBuiltInThemes") {
            let registry = ThemeRegistry()
            s.expectEqual(registry.themes.count, 3)
            s.expectNotNil(registry.theme(for: "classic"))
            s.expectNotNil(registry.theme(for: "dark-green"))
            s.expectNotNil(registry.theme(for: "dark-blue"))
        }

        await s.test("test_registry_defaultThemeIsClassic") {
            let registry = ThemeRegistry()
            s.expectEqual(registry.defaultThemeID, "classic")
            s.expectNotNil(registry.theme(for: "classic"))
        }

        await s.test("test_registry_registerCustomTheme_addsToList") {
            let registry = ThemeRegistry()
            registry.register(FakeTheme(id: "custom"))
            s.expectEqual(registry.themes.count, 4)
            s.expectNotNil(registry.theme(for: "custom"))
        }

        await s.test("test_registry_registerDuplicateID_replacesExisting") {
            let registry = ThemeRegistry()
            let fake = FakeTheme(id: "classic", displayName: "FakeClassic")
            registry.register(fake)
            s.expectEqual(registry.themes.count, 3, "count should not increase")
            let found = registry.theme(for: "classic")
            s.expectEqual(found?.displayName, "FakeClassic", "should be replaced")
        }

        await s.test("test_registry_themeForUnknownID_returnsNil") {
            let registry = ThemeRegistry()
            s.expectNil(registry.theme(for: "nonexistent"))
        }

        await s.test("test_registry_allThemesConformToProtocol") {
            let registry = ThemeRegistry()
            for theme in registry.themes {
                s.expect(!theme.id.isEmpty, "id should be non-empty")
                s.expect(!theme.displayName.isEmpty, "displayName should be non-empty")
                // Colors exist (non-nil by protocol requirement)
            }
        }
    }
}

// MARK: - ThemeManager Tests

func registerThemeManagerSuites(_ runner: TestRunner) {
    runner.suite("ThemeManager (5.2)") { s in

        await s.test("test_manager_defaultsToClassicTheme") { @MainActor in
            let defaults = UserDefaults(suiteName: "test_manager_defaults")!
            defaults.removePersistentDomain(forName: "test_manager_defaults")
            let registry = ThemeRegistry()
            let manager = await ThemeManager(registry: registry, defaults: defaults)
            let id = await manager.currentTheme.id
            s.expectEqual(id, "classic")
        }

        await s.test("test_manager_selectTheme_updatesCurrentTheme") { @MainActor in
            let defaults = UserDefaults(suiteName: "test_manager_select")!
            defaults.removePersistentDomain(forName: "test_manager_select")
            let registry = ThemeRegistry()
            let manager = await ThemeManager(registry: registry, defaults: defaults)
            await manager.selectTheme("dark-green")
            let id = await manager.currentTheme.id
            s.expectEqual(id, "dark-green")
        }

        await s.test("test_manager_selectTheme_persistsToUserDefaults") { @MainActor in
            let suiteName = "test_manager_persist"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            let registry = ThemeRegistry()
            let manager = await ThemeManager(registry: registry, defaults: defaults)
            await manager.selectTheme("dark-blue")
            let saved = defaults.string(forKey: "selectedThemeID")
            s.expectEqual(saved, "dark-blue")
        }

        await s.test("test_manager_restoresPersistedTheme") { @MainActor in
            let suiteName = "test_manager_restore"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            defaults.set("dark-green", forKey: "selectedThemeID")
            let registry = ThemeRegistry()
            let manager = await ThemeManager(registry: registry, defaults: defaults)
            let id = await manager.currentTheme.id
            s.expectEqual(id, "dark-green")
        }

        await s.test("test_manager_invalidPersistedID_fallsBackToDefault") { @MainActor in
            let suiteName = "test_manager_fallback"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            defaults.set("nonexistent", forKey: "selectedThemeID")
            let registry = ThemeRegistry()
            let manager = await ThemeManager(registry: registry, defaults: defaults)
            let id = await manager.currentTheme.id
            s.expectEqual(id, "classic")
        }

        await s.test("test_manager_selectUnknownTheme_noChange") { @MainActor in
            let suiteName = "test_manager_unknown"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            let registry = ThemeRegistry()
            let manager = await ThemeManager(registry: registry, defaults: defaults)
            await manager.selectTheme("dark-green")
            await manager.selectTheme("nonexistent")
            let id = await manager.currentTheme.id
            s.expectEqual(id, "dark-green", "should remain unchanged")
        }
    }
}

// MARK: - Built-in Theme Validation Tests

func registerBuiltInThemeSuites(_ runner: TestRunner) {
    runner.suite("Built-in Themes (5.1)") { s in

        await s.test("test_classicTheme_hasExpectedProperties") {
            let theme = ClassicTheme()
            s.expectEqual(theme.id, "classic")
            s.expectEqual(theme.displayName, "Classic")
            s.expectNil(theme.preferredColorScheme, "Classic follows system")
        }

        await s.test("test_darkGreenTheme_hasExpectedProperties") {
            let theme = DarkGreenTheme()
            s.expectEqual(theme.id, "dark-green")
            s.expectEqual(theme.displayName, "Dark Green")
            s.expectEqual(theme.preferredColorScheme, .dark)
        }

        await s.test("test_darkBlueTheme_hasExpectedProperties") {
            let theme = DarkBlueTheme()
            s.expectEqual(theme.id, "dark-blue")
            s.expectEqual(theme.displayName, "Dark Blue")
            s.expectEqual(theme.preferredColorScheme, .dark)
        }
    }
}
