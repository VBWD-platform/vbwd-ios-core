import Foundation

/// Transport/error model. Port of the web `ApiError`:
/// non-2xx → `.http`, network failure → `.transport`, body decode failure →
/// `.decoding`. `notImplemented` backs deferred features (e.g. token refresh).
public enum APIError: Error, Equatable {
    case http(status: Int, message: String)
    case transport(message: String)
    case decoding(message: String)
    case notImplemented(String)

    /// Unified human-readable message regardless of case.
    public var message: String {
        switch self {
        case let .http(_, m), let .transport(m), let .decoding(m), let .notImplemented(m):
            return m
        }
    }

    /// Builds an `.http` error, extracting the message the way the web client
    /// did: response body `error`, then `message`, else the HTTP status text.
    public static func fromResponse(status: Int, body: Data, statusText: String) -> APIError {
        .http(status: status, message: messageFromBody(body) ?? statusText)
    }

    public static func fromTransport(_ error: Error) -> APIError {
        .transport(message: (error as NSError).localizedDescription)
    }

    public static func fromDecoding(_ error: Error) -> APIError {
        .decoding(message: "\(error)")
    }

    static func messageFromBody(_ data: Data) -> String? {
        guard
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if let e = obj["error"] as? String, !e.isEmpty { return e }
        if let m = obj["message"] as? String, !m.isEmpty { return m }
        return nil
    }
}
