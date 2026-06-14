import Foundation
import VBWDCore
import VBWDCoreTestKit

// Entry point. Each subsprint registers its suites here; the process exits
// non-zero if any test fails (Red), zero when all pass (Green).
func runAll() async -> Int32 {
    let runner = TestRunner()

    // Subsprint 1.0
    runner.suite("Smoke (1.0)") { s in
        await s.test("package_linksAndTestRunnerWorks") {
            s.expectEqual(VBWDCore.apiContractVersion, "v1")
        }
    }

    // Subsprint 1.1
    registerNetworkingSuites(runner)
    registerPersistenceSuites(runner)

    // Subsprint 1.2
    registerDomainSuites(runner)

    // Subsprint 1.3
    registerSessionUISuites(runner)

    // Subsprint 1.4
    registerCompositionSuites(runner)

    // Sprint 02
    registerPluginContractSuites(runner)   // 2.1
    registerPlatformSDKSuites(runner)      // 2.2
    registerEventBusSuites(runner)         // 2.3
    registerPluginRegistrySuites(runner)   // 2.4
    registerAppShellSuites(runner)         // 2.5
    registerExamplePluginSuites(runner)    // 2.6
    registerPluginHostSuites(runner)       // 2.7

    // Sprint 04
    registerProfileServiceSuites(runner)   // 4.0–4.1
    registerProfileViewModelSuites(runner) // 4.2

    // Sprint 05
    registerThemeRegistrySuites(runner)    // 5.0
    registerBuiltInThemeSuites(runner)     // 5.1
    registerThemeManagerSuites(runner)     // 5.2

    // Sprint 06
    registerStoreAndBillingSuites(runner)          // 6.0
    registerCheckoutSuites(runner)                 // 6.1
    registerCartAndCheckoutSourceSuites(runner)    // 6.2
    registerInvoiceDetailSuites(runner)            // 6.3

    // Sprint 67.2 — notifications, device-token relay, menu badge
    registerNotificationsSuites(runner)

    return await runner.run()
}

let code = await runAll()
exit(code)
