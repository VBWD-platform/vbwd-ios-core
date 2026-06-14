import Foundation
import VBWDCore
import VBWDCoreTestKit

// MARK: - S67.2 doubles

/// Records every token the notifications seam hands to it.
private actor RecordingTokenSink: DeviceTokenSink {
    private(set) var tokens: [String] = []
    func handleDeviceToken(_ tokenHex: String) async { tokens.append(tokenHex) }
    func received() -> [String] { tokens }
}

/// Records every badge count the SDK applies (replaces UNUserNotificationCenter).
private actor BadgeRecorder {
    private(set) var counts: [Int] = []
    func record(_ count: Int) { counts.append(count) }
    func all() -> [Int] { counts }
}

func registerNotificationsSuites(_ runner: TestRunner) {

    // MARK: S67a — DefaultNotificationsSDK token relay + badge
    runner.suite("S67a DefaultNotificationsSDK") { s in
        await s.test("forwards_token_to_registered_sink") {
            let sdk = DefaultNotificationsSDK(badgeSetter: { _ in })
            let sink = RecordingTokenSink()
            await sdk.registerSink(sink)
            await sdk.didReceiveDeviceToken("aa11")
            let got = await sink.received()
            s.expectEqual(got, ["aa11"])
        }
        await s.test("replays_latest_token_to_new_sink") {
            let sdk = DefaultNotificationsSDK(badgeSetter: { _ in })
            await sdk.didReceiveDeviceToken("aa11")
            await sdk.didReceiveDeviceToken("bb22")
            let lateSink = RecordingTokenSink()
            await sdk.registerSink(lateSink)
            let got = await lateSink.received()
            s.expectEqual(got, ["bb22"],
                          "late sink must get exactly the latest token")
        }
        await s.test("no_token_yet_means_no_replay") {
            let sdk = DefaultNotificationsSDK(badgeSetter: { _ in })
            let sink = RecordingTokenSink()
            await sdk.registerSink(sink)
            let got = await sink.received()
            s.expect(got.isEmpty, "sink must not be called before a token exists")
        }
        await s.test("set_app_icon_badge_clamps_negative_to_zero") {
            let recorder = BadgeRecorder()
            let sdk = DefaultNotificationsSDK(badgeSetter: { count in
                await recorder.record(count)
            })
            await sdk.setAppIconBadge(-5)
            await sdk.setAppIconBadge(3)
            let got = await recorder.all()
            s.expectEqual(got, [0, 3])
        }
    }

    // MARK: S67b — MenuItem badge pill
    runner.suite("S67b MenuItem badge") { s in
        await s.test("badgeProvider_defaultsToNil_zeroImpactOnExistingItems") {
            let item = MenuItem(id: "x", icon: "circle", title: "X")
            s.expectNil(item.badgeProvider)
        }
        await s.test("menu_renders_pill_when_badge_positive") { @MainActor in
            let provider = BadgeProvider(count: 5)
            let item = MenuItem(id: "x", icon: "circle", title: "X",
                                badgeProvider: provider)
            s.expectEqual(item.badgeProvider?.count, 5)
            s.expectEqual(MenuBadgePill.label(for: 5), "5")
        }
        await s.test("pill_hidden_at_zero_and_negative") {
            s.expectNil(MenuBadgePill.label(for: 0))
            s.expectNil(MenuBadgePill.label(for: -2))
        }
    }

    // MARK: S67c — logout event seam (drives plugin device-token unregister)
    runner.suite("S67c AuthSession logout event") { s in
        await s.test("signOut_emits_authLogout") { @MainActor in
            let bus = DefaultEventBus(api: SpyAPIClient())
            nonisolated(unsafe) var emitted = false
            bus.on(AppEvents.authLogout) { _ in emitted = true }
            try? await Task.sleep(nanoseconds: 50_000_000)
            let session = AuthSession(service: SpyAuthService(), events: bus)
            await session.signOut()
            try? await Task.sleep(nanoseconds: 50_000_000)
            s.expect(emitted, "signOut must emit AppEvents.authLogout")
        }
    }

    // MARK: S67d — PlatformSDK facade exposes the seam
    runner.suite("S67d PlatformSDK notifications seam") { s in
        await s.test("defaultPlatformSDK_exposes_injected_notifications") { @MainActor in
            let api = SpyAPIClient()
            let notifications = DefaultNotificationsSDK(badgeSetter: { _ in })
            let sdk = DefaultPlatformSDK(
                api: api,
                apiConfig: APIClientConfig(baseURL: SDKContainer.defaultBaseURL),
                events: DefaultEventBus(api: api),
                cart: Cart(),
                checkoutSources: CheckoutSourceRegistry(),
                notifications: notifications)
            s.expect((sdk.notifications as? DefaultNotificationsSDK) === notifications,
                     "facade must hand plugins the injected seam instance")
        }
    }
}
