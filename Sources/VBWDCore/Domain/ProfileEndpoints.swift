/// Profile endpoint paths. Matches the web `Profile.vue` API calls.
/// All paths are overridable (OCP).
public struct ProfileEndpoints: Equatable, Sendable {
    public var profile: String
    public var updateDetails: String
    public var changePassword: String

    public init(profile: String = "/user/profile",
                updateDetails: String = "/user/details",
                changePassword: String = "/user/change-password") {
        self.profile = profile
        self.updateDetails = updateDetails
        self.changePassword = changePassword
    }
}
