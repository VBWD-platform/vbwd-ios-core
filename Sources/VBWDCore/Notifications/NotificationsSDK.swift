import Foundation

/// Core notifications seam (S67.2). The host app's `UIApplicationDelegate`
/// forwards the APNs device token here; plugins register a `DeviceTokenSink`
/// so they can ship the token to their own backend endpoint
/// (e.g. `POST /api/v1/devices/register`) — core stays agnostic of any
/// plugin wire contract.
public protocol NotificationsSDK: Sendable {
    /// Called once per app launch when APNs returns a token (hex-encoded).
    func didReceiveDeviceToken(_ tokenHex: String) async
    /// Plugin registers a sink so it can call its own backend endpoint with
    /// the token. If a token is already known it is replayed immediately.
    func registerSink(_ sink: DeviceTokenSink) async
    /// Drives the app-icon badge. Plugins call this when their inbox feed
    /// reports a new unread total. Negative counts are clamped to zero.
    func setAppIconBadge(_ count: Int) async
}

/// Receives the APNs device token — immediately on registration when a token
/// is already buffered, and again whenever APNs issues a new one.
public protocol DeviceTokenSink: Sendable {
    func handleDeviceToken(_ tokenHex: String) async
}
