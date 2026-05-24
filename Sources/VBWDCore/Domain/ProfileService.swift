import Foundation

/// Profile orchestration contract. Port of the web `profile.ts` store actions.
/// ViewModels depend on this protocol, never on the concrete service (DIP).
public protocol ProfileService: AnyObject, Sendable {
    /// GET /user/profile — fetches the full profile.
    func fetchProfile() async throws -> UserProfile
    /// PUT /user/details — updates personal info + address fields.
    func updateDetails(_ profile: UserProfile) async throws -> UserProfile
    /// POST /user/change-password — changes the user password.
    func changePassword(current: String, new: String) async throws
}

/// Default `ProfileService`. Depends only on injected protocols (DIP).
public final class DefaultProfileService: ProfileService, @unchecked Sendable {
    private let client: APIClient
    private let endpoints: ProfileEndpoints

    public init(client: APIClient,
                endpoints: ProfileEndpoints = ProfileEndpoints()) {
        self.client = client
        self.endpoints = endpoints
    }

    public func fetchProfile() async throws -> UserProfile {
        let response: ProfileResponse = try await client.get(endpoints.profile)
        guard let details = response.details else {
            throw APIError.decoding(message: "Missing details in profile response")
        }
        return details
    }

    public func updateDetails(_ profile: UserProfile) async throws -> UserProfile {
        let response: UpdateDetailsResponse = try await client.put(
            endpoints.updateDetails, body: profile)
        guard let details = response.details else {
            throw APIError.decoding(message: "Missing details in update response")
        }
        return details
    }

    public func changePassword(current: String, new newPassword: String) async throws {
        struct Body: Encodable {
            let currentPassword: String
            let newPassword: String
        }
        let _: ChangePasswordResponse = try await client.post(
            endpoints.changePassword,
            body: Body(currentPassword: current, newPassword: newPassword))
    }
}
