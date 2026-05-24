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

    public init(baseURL: URL,
                timeout: TimeInterval = APIClientConfig.defaultTimeout,
                headers: [String: String] = [:]) {
        self.baseURL = baseURL
        self.timeout = timeout
        // Default first, caller-supplied headers override (web spread order).
        var merged = ["Content-Type": "application/json"]
        for (k, v) in headers { merged[k] = v }
        self.headers = merged
    }
}
