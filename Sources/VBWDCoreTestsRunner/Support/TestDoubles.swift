import Foundation
import VBWDCore

// MARK: - StubURLProtocol (no sockets)

/// Intercepts URLSession requests so `URLSessionAPIClient` is tested without
/// network. Handler maps a request → (status, body); the last request is kept
/// for header/method/body assertions.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static var lastRequest: URLRequest?

    static func session() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: cfg)
    }

    static func bodyData(_ r: URLRequest) -> Data? {
        if let b = r.httpBody { return b }
        guard let s = r.httpBodyStream else { return nil }
        s.open(); defer { s.close() }
        var data = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        while s.hasBytesAvailable {
            let n = s.read(&buf, maxLength: buf.count)
            if n <= 0 { break }
            data.append(buf, count: n)
        }
        return data
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        StubURLProtocol.lastRequest = request
        let (status, data) = StubURLProtocol.handler?(request) ?? (200, Data())
        let resp = HTTPURLResponse(url: request.url!, statusCode: status,
                                   httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

// MARK: - SpyAPIClient

/// In-memory `APIClient` for domain tests. Maps router output through the SAME
/// status/decoding rules as `URLSessionAPIClient`, so the Liskov contract is
/// behaviourally meaningful. Records calls and `setToken` for assertions.
final class SpyAPIClient: APIClient, @unchecked Sendable {
    typealias Router = (_ path: String, _ method: HTTPMethod, _ body: Data?) -> (Int, Data)

    var router: Router
    private(set) var calls: [(path: String, method: HTTPMethod, body: Data?)] = []
    private(set) var tokenHistory: [String?] = []
    private var handlers: [APIEvent: [() -> Void]] = [:]

    init(router: @escaping Router = { _, _, _ in (404, Data("{\"error\":\"no route\"}".utf8)) }) {
        self.router = router
    }

    func get<R: Decodable>(_ path: String) async throws -> R {
        try route(path, .get, nil)
    }
    func post<R: Decodable>(_ path: String, body: (any Encodable)?) async throws -> R {
        try route(path, .post, encode(body))
    }
    func put<R: Decodable>(_ path: String, body: (any Encodable)?) async throws -> R {
        try route(path, .put, encode(body))
    }
    func patch<R: Decodable>(_ path: String, body: (any Encodable)?) async throws -> R {
        try route(path, .patch, encode(body))
    }
    func delete<R: Decodable>(_ path: String) async throws -> R {
        try route(path, .delete, nil)
    }
    func setToken(_ token: String?) { tokenHistory.append(token) }
    func on(_ event: APIEvent, _ handler: @escaping () -> Void) {
        handlers[event, default: []].append(handler)
    }

    private func encode(_ body: (any Encodable)?) -> Data? {
        guard let body else { return nil }
        return try? JSONEncoder().encode(AnyEncodableShim(body))
    }

    private func route<R: Decodable>(_ path: String, _ method: HTTPMethod, _ body: Data?) throws -> R {
        calls.append((path, method, body))
        let (status, data) = router(path, method, body)
        if status == 401 { handlers[.tokenExpired]?.forEach { $0() } }
        guard (200..<300).contains(status) else {
            throw APIError.fromResponse(status: status, body: data,
                                        statusText: "HTTP \(status)")
        }
        if R.self == EmptyResponse.self, let e = EmptyResponse() as? R { return e }
        do { return try JSONDecoder().decode(R.self, from: data) }
        catch { throw APIError.fromDecoding(error) }
    }
}

/// Local type-eraser (the SDK's `AnyEncodable` is internal to its module).
struct AnyEncodableShim: Encodable, @unchecked Sendable {
    private let f: (Encoder) throws -> Void
    init(_ w: any Encodable) { f = { try w.encode(to: $0) } }
    func encode(to e: Encoder) throws { try f(e) }
}

// MARK: - Shared contract router (Liskov)

enum Contract {
    struct Echo: Codable, Equatable { let value: String }

    /// One backend definition both clients are tested against.
    static func route(_ path: String, _ method: HTTPMethod, _ body: Data?) -> (Int, Data) {
        switch (method, path) {
        case (.get, "/thing"):
            return (200, try! JSONEncoder().encode(Echo(value: "hello")))
        case (.post, "/echo"):
            return (200, body ?? Data())
        case (.get, "/boom"):
            return (500, Data("{\"error\":\"boom\"}".utf8))
        default:
            return (404, Data("{\"error\":\"not found\"}".utf8))
        }
    }
}
