import Foundation

/// Transport configuration. Port of the web `ApiClientConfig`:
/// `baseURL`, `timeout` (default 30s — web used 30000ms), and headers with a
/// default `Content-Type: application/json` that callers may override.
public struct APIClientConfig: Equatable, Sendable {
    /// Web parity: `ApiClient` default timeout was 30000ms.
    public static let defaultTimeout: TimeInterval = 30

    public let baseURL: URL
    public let timeout: TimeInterval
    public let headers: [String: String]
    /// HTTP traffic logger. Defaults to `.bodies` in DEBUG, `.off` in
    /// release. Override to silence logs in DEBUG (e.g. on a noisy CI run)
    /// or to opt-in in release for forensic capture.
    public let logging: APITrafficLogger

    public init(baseURL: URL,
                timeout: TimeInterval = APIClientConfig.defaultTimeout,
                headers: [String: String] = [:],
                logging: APITrafficLogger = .default) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.logging = logging
        // Default first, caller-supplied headers override (web spread order).
        var merged = ["Content-Type": "application/json"]
        #if os(iOS)
        merged["X-Client-Platform"] = "ios"
        #elseif os(macOS)
        merged["X-Client-Platform"] = "macos"
        #endif
        for (k, v) in headers { merged[k] = v }
        self.headers = merged
    }
}
