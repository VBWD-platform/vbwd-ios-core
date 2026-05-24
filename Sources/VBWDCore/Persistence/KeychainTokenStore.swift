import Foundation
import Security

/// The only Keychain (`SecItem*`) site in the SDK (enforced by boundary-lint).
/// On-device replacement for the web `localStorage`; behaviourally substitutable
/// for `InMemoryTokenStore` (proven by the shared `TokenStore` contract).
public final class KeychainTokenStore: TokenStore, @unchecked Sendable {
    private let service: String
    private enum Account: String { case token, refresh, user }

    public init(service: String = "com.vbwd.sdk.auth") {
        self.service = service
    }

    public func saveToken(_ token: String) throws {
        try save(Data(token.utf8), .token)
    }
    public func loadToken() throws -> String? {
        try load(.token).map { String(decoding: $0, as: UTF8.self) }
    }
    public func saveRefreshToken(_ token: String) throws {
        try save(Data(token.utf8), .refresh)
    }
    public func loadRefreshToken() throws -> String? {
        try load(.refresh).map { String(decoding: $0, as: UTF8.self) }
    }
    public func saveUser(_ data: Data) throws { try save(data, .user) }
    public func loadUser() throws -> Data? { try load(.user) }

    public func clear() throws {
        for a in [Account.token, .refresh, .user] { try delete(a) }
    }

    // MARK: - Keychain primitives

    private func baseQuery(_ account: Account) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
        ]
    }

    private func save(_ data: Data, _ account: Account) throws {
        try delete(account)
        var q = baseQuery(account)
        q[kSecValueData as String] = data
        let status = SecItemAdd(q as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status) }
    }

    private func load(_ account: Account) throws -> Data? {
        var q = baseQuery(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &out)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError(status) }
        return out as? Data
    }

    private func delete(_ account: Account) throws {
        let status = SecItemDelete(baseQuery(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status)
        }
    }
}

public struct KeychainError: Error, Equatable {
    public let status: OSStatus
    init(_ status: OSStatus) { self.status = status }
}
