import Foundation
import UserNotifications

/// Default `NotificationsSDK`: buffers the latest APNs token in memory,
/// forwards it to every registered sink, and replays it to sinks that
/// register later (the token usually arrives before any plugin is ready —
/// or before the user is even logged in).
///
/// The app-icon badge is applied via `UNUserNotificationCenter.setBadgeCount`;
/// tests inject a `badgeSetter` so they never touch the notification center.
public actor DefaultNotificationsSDK: NotificationsSDK {
    /// Process-wide instance. The host app's `UIApplicationDelegate` lives
    /// outside the DI graph, so it posts tokens here; `SDKContainer` hands
    /// the same instance to the plugin facade.
    public static let shared = DefaultNotificationsSDK()

    public typealias BadgeSetter = @Sendable (Int) async -> Void

    private var latestTokenHex: String?
    private var sinks: [DeviceTokenSink] = []
    private let badgeSetter: BadgeSetter

    /// - Parameter badgeSetter: injectable for tests. The default applies the
    ///   count through `UNUserNotificationCenter` (errors are best-effort
    ///   ignored — a denied permission must never break callers).
    public init(badgeSetter: BadgeSetter? = nil) {
        self.badgeSetter = badgeSetter ?? { count in
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }

    /// Latest APNs token the system has handed us this process. Nil
    /// until `didRegisterForRemoteNotificationsWithDeviceToken` fires.
    /// Plugins read this when they need to identify *this device* to the
    /// backend (S68: same-device push suppression).
    public func currentTokenHex() async -> String? { latestTokenHex }

    public func didReceiveDeviceToken(_ tokenHex: String) async {
        latestTokenHex = tokenHex
        for sink in sinks {
            await sink.handleDeviceToken(tokenHex)
        }
    }

    public func registerSink(_ sink: DeviceTokenSink) async {
        sinks.append(sink)
        if let tokenHex = latestTokenHex {
            await sink.handleDeviceToken(tokenHex)
        }
    }

    public func setAppIconBadge(_ count: Int) async {
        await badgeSetter(max(0, count))
    }
}
