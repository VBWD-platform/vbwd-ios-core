import Foundation

/// Events the client emits. Port of the web `ApiEvent` ('token-expired').
public enum APIEvent: Hashable, Sendable {
    case tokenExpired
}

/// Type-erased `Encodable` so request bodies can be passed as `any Encodable`
/// (web accepted arbitrary JSON bodies). Single definition (DRY).
struct AnyEncodable: Encodable {
    private let encodeTo: (Encoder) throws -> Void
    init(_ wrapped: any Encodable) { encodeTo = { try wrapped.encode(to: $0) } }
    func encode(to encoder: Encoder) throws { try encodeTo(encoder) }
}

/// Transport contract. Port of the web `ApiClient` public surface. Domain code
/// depends on this protocol, never on `URLSessionAPIClient` (DIP).
public protocol APIClient: AnyObject, Sendable {
    func get<R: Decodable>(_ path: String) async throws -> R
    func post<R: Decodable>(_ path: String, body: (any Encodable)?) async throws -> R
    func put<R: Decodable>(_ path: String, body: (any Encodable)?) async throws -> R
    func patch<R: Decodable>(_ path: String, body: (any Encodable)?) async throws -> R
    func delete<R: Decodable>(_ path: String) async throws -> R

    /// Raw data download (e.g. PDF). Returns the response body without JSON
    /// decoding. Not all implementations support this; the default throws.
    func getData(_ path: String) async throws -> Data

    /// Multipart file upload. Sends the file as `multipart/form-data` with
    /// the given `fileFieldName` and additional text fields from `fields`.
    func upload<R: Decodable>(_ path: String,
                               fileFieldName: String,
                               fileData: Data, fileName: String,
                               mimeType: String, fields: [String: String]) async throws -> R

    /// Set/clear the bearer token (web `setToken`/`clearToken`).
    func setToken(_ token: String?)

    /// Subscribe to a transport event (web `on`).
    func on(_ event: APIEvent, _ handler: @escaping @Sendable () -> Void)
}

public extension APIClient {
    func post<R: Decodable>(_ path: String) async throws -> R {
        try await post(path, body: nil)
    }
    func put<R: Decodable>(_ path: String) async throws -> R {
        try await put(path, body: nil)
    }
    func getData(_ path: String) async throws -> Data {
        throw APIError.transport(message: "getData not supported")
    }
    func upload<R: Decodable>(_ path: String,
                               fileFieldName: String,
                               fileData: Data, fileName: String,
                               mimeType: String, fields: [String: String]) async throws -> R {
        throw APIError.transport(message: "upload not supported")
    }

    /// Convenience overload defaulting the multipart file field name to `"file"`.
    func upload<R: Decodable>(_ path: String, fileData: Data, fileName: String,
                               mimeType: String, fields: [String: String]) async throws -> R {
        try await upload(path,
                         fileFieldName: "file",
                         fileData: fileData,
                         fileName: fileName,
                         mimeType: mimeType,
                         fields: fields)
    }
}
