import Foundation

/// The only `URLSession` site in the SDK (enforced by boundary-lint).
/// Port of the web axios-based `ApiClient`: Bearer injection, JSON bodies,
/// non-2xx → mapped `APIError`, 401 → `tokenExpired` event.
public final class URLSessionAPIClient: APIClient, @unchecked Sendable {
    private let config: APIClientConfig
    private let session: URLSession
    private let tokenProvider: AuthTokenProvider
    
    private actor HandlerState {
        var handlers: [APIEvent: [@Sendable () -> Void]] = [:]
        
        func addHandler(_ event: APIEvent, _ handler: @escaping @Sendable () -> Void) {
            handlers[event, default: []].append(handler)
        }
        
        func getHandlers(_ event: APIEvent) -> [@Sendable () -> Void] {
            handlers[event] ?? []
        }
    }
    
    private let handlerState = HandlerState()

    public init(config: APIClientConfig,
                session: URLSession = .shared,
                tokenProvider: AuthTokenProvider = MutableTokenProvider()) {
        self.config = config
        self.session = session
        self.tokenProvider = tokenProvider
    }

    public func get<R: Decodable>(_ path: String) async throws -> R {
        try await send(path, .get, body: nil)
    }
    public func post<R: Decodable>(_ path: String, body: (any Encodable)?) async throws -> R {
        try await send(path, .post, body: body)
    }
    public func put<R: Decodable>(_ path: String, body: (any Encodable)?) async throws -> R {
        try await send(path, .put, body: body)
    }
    public func patch<R: Decodable>(_ path: String, body: (any Encodable)?) async throws -> R {
        try await send(path, .patch, body: body)
    }
    public func delete<R: Decodable>(_ path: String) async throws -> R {
        try await send(path, .delete, body: nil)
    }

    public func getData(_ path: String) async throws -> Data {
        var request = URLRequest(url: makeURL(path))
        request.httpMethod = HTTPMethod.get.rawValue
        request.timeoutInterval = config.timeout
        if let token = tokenProvider.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.fromTransport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport(message: "Non-HTTP response")
        }

        if http.statusCode == 401 { emit(.tokenExpired) }

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.fromResponse(
                status: http.statusCode,
                body: data,
                statusText: HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
        }

        return data
    }

    public func setToken(_ token: String?) { tokenProvider.token = token }

    public nonisolated func on(_ event: APIEvent, _ handler: @escaping @Sendable () -> Void) {
        Task {
            await handlerState.addHandler(event, handler)
        }
    }

    // MARK: - Core

    private func send<R: Decodable>(_ path: String,
                                    _ method: HTTPMethod,
                                    body: (any Encodable)?) async throws -> R {
        var request = URLRequest(url: makeURL(path))
        request.httpMethod = method.rawValue
        request.timeoutInterval = config.timeout
        for (k, v) in config.headers { request.setValue(v, forHTTPHeaderField: k) }
        if let token = tokenProvider.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.fromTransport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport(message: "Non-HTTP response")
        }

        if http.statusCode == 401 { emit(.tokenExpired) }

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.fromResponse(
                status: http.statusCode,
                body: data,
                statusText: HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            )
        }

        if R.self == EmptyResponse.self, let empty = EmptyResponse() as? R {
            return empty
        }
        do {
            return try JSONDecoder().decode(R.self, from: data)
        } catch {
            throw APIError.fromDecoding(error)
        }
    }

    private func makeURL(_ path: String) -> URL {
        if let abs = URL(string: path), abs.scheme != nil { return abs }
        return URL(string: config.baseURL.absoluteString + path) ?? config.baseURL
    }

    private nonisolated func emit(_ event: APIEvent) {
        Task {
            let handlers = await handlerState.getHandlers(event)
            handlers.forEach { $0() }
        }
    }
}

/// Decode target for endpoints with no/empty body (e.g. logout).
public struct EmptyResponse: Codable, Equatable, Sendable {
    public init() {}
}
