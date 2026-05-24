/// `/auth/login` response. Matches the live backend shape:
/// `{ error, success, token, user, user_id }` (web `LoginResponse` + extras).
public struct LoginResponse: Codable, Equatable, Sendable {
    public let success: Bool?
    public let token: String?
    public let refreshToken: String?
    public let user: AuthUser?
    public let userId: String?
    public let error: String?

    enum CodingKeys: String, CodingKey {
        case success, token, user, error
        case refreshToken = "refresh_token"
        case userId = "user_id"
    }
}
