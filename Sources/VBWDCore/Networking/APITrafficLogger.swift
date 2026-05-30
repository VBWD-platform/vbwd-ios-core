import Foundation
import os

/// Structured HTTP traffic logger. Writes a one-line summary per
/// request/response into the unified logging system (subsystem
/// `cc.vbwd.api`, category `traffic`) — visible in Xcode's console pane
/// and `Console.app`, filterable by `subsystem:cc.vbwd.api`.
///
/// Default: `.bodies` in DEBUG (everything is captured so you can verify
/// e2e_v1 envelope payloads are opaque), `.off` in release. Host apps can
/// override via `APIClientConfig.logging`.
///
/// **Privacy:** request + response bodies for auth paths are redacted so
/// passwords and bearer tokens don't end up in the device log. The
/// `Authorization` header is never serialized by this type — it never
/// touches the request body, only the URLRequest header which we don't log.
public struct APITrafficLogger: Sendable, Equatable {

    public static func == (lhs: APITrafficLogger, rhs: APITrafficLogger) -> Bool {
        lhs.level == rhs.level && lhs.bodyCap == rhs.bodyCap
    }

    public enum Level: Sendable, Equatable {
        /// No logging at all.
        case off
        /// `→ METHOD path` and `← status METHOD path` — no bodies.
        case summary
        /// Same as `.summary` plus body previews (truncated at `bodyCap`).
        case bodies
    }

    public let level: Level
    /// Body preview cap in bytes. Defaults to 4 KiB.
    public let bodyCap: Int

    private let logger = Logger(subsystem: "cc.vbwd.api", category: "traffic")

    public init(level: Level, bodyCap: Int = 4096) {
        self.level = level
        self.bodyCap = bodyCap
    }

    /// `bodies` in DEBUG, `off` in release.
    public static let `default`: APITrafficLogger = {
        #if DEBUG
        return APITrafficLogger(level: .bodies)
        #else
        return APITrafficLogger(level: .off)
        #endif
    }()

    public static let off = APITrafficLogger(level: .off)

    // MARK: - Public entry points (called from URLSessionAPIClient)

    public func logRequest(method: String, url: URL, body: Data?) {
        guard level != .off else { return }
        var line = "→ \(method) \(displayPath(url))"
        if level == .bodies {
            let bodyPreview = redactedBodyPreview(url: url, body: body, isRequest: true)
            if !bodyPreview.isEmpty {
                line += "\n   body: \(bodyPreview)"
            }
        }
        logger.debug("\(line, privacy: .public)")
    }

    public func logResponse(method: String, url: URL, status: Int, body: Data) {
        guard level != .off else { return }
        var line = "← \(status) \(method) \(displayPath(url))"
        if level == .bodies {
            let bodyPreview = redactedBodyPreview(url: url, body: body, isRequest: false)
            if !bodyPreview.isEmpty {
                line += "\n   body: \(bodyPreview)"
            }
        }
        logger.debug("\(line, privacy: .public)")
    }

    public func logTransportError(method: String, url: URL, error: Error) {
        guard level != .off else { return }
        let line = "✗ \(method) \(displayPath(url)) — \(error)"
        logger.error("\(line, privacy: .public)")
    }

    // MARK: - Formatting

    private func displayPath(_ url: URL) -> String {
        var s = url.path
        if let q = url.query, !q.isEmpty { s += "?\(q)" }
        return s
    }

    private func redactedBodyPreview(url: URL, body: Data?, isRequest: Bool) -> String {
        guard let body, !body.isEmpty else { return "" }
        // Redact secrets on the auth surface — login passwords + responses
        // containing access tokens. Both directions wiped to a single tag.
        if url.path.contains("/auth/") {
            return "<redacted: auth body>"
        }
        let prefix = body.prefix(bodyCap)
        let utf8 = String(data: prefix, encoding: .utf8)
        let preview = utf8 ?? "<\(body.count) bytes — non-utf8>"
        return body.count > bodyCap
            ? "\(preview)… (\(body.count) bytes total)"
            : preview
    }
}
