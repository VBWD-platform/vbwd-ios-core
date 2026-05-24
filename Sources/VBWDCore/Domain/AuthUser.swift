/// Access level (web `AccessLevel` / `UserAccessLevel` — same shape).
public struct AccessLevel: Codable, Equatable, Sendable {
    public let id: String
    public let slug: String
    public let name: String
}

/// Authenticated user. Port of the web `AuthUser` with snake_case mapping,
/// matching the live backend `/auth/login` `user` object.
public struct AuthUser: Codable, Equatable, Sendable {
    public let id: String
    public let email: String
    public let name: String?
    public let role: String?
    public let isAdmin: Bool?
    public let accessLevels: [AccessLevel]?
    public let permissions: [String]?
    public let userAccessLevels: [AccessLevel]?
    public let userPermissions: [String]?

    enum CodingKeys: String, CodingKey {
        case id, email, name, role, permissions
        case isAdmin = "is_admin"
        case accessLevels = "access_levels"
        case userAccessLevels = "user_access_levels"
        case userPermissions = "user_permissions"
    }

    public init(id: String, email: String, name: String? = nil, role: String? = nil,
                isAdmin: Bool? = nil, accessLevels: [AccessLevel]? = nil,
                permissions: [String]? = nil, userAccessLevels: [AccessLevel]? = nil,
                userPermissions: [String]? = nil) {
        self.id = id
        self.email = email
        self.name = name
        self.role = role
        self.isAdmin = isAdmin
        self.accessLevels = accessLevels
        self.permissions = permissions
        self.userAccessLevels = userAccessLevels
        self.userPermissions = userPermissions
    }
}
