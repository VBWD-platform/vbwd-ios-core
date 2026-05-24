import Foundation

/// Form data for personal info + address fields.
public struct ProfileFormData: Equatable, Sendable {
    public var firstName: String = ""
    public var lastName: String = ""
    public var company: String = ""
    public var taxNumber: String = ""
    public var phone: String = ""
    public var addressLine1: String = ""
    public var addressLine2: String = ""
    public var city: String = ""
    public var postalCode: String = ""
    public var country: String = ""

    public init() {}

    init(from profile: UserProfile) {
        firstName = profile.firstName
        lastName = profile.lastName
        company = profile.company
        taxNumber = profile.taxNumber
        phone = profile.phone
        addressLine1 = profile.addressLine1
        addressLine2 = profile.addressLine2
        city = profile.city
        postalCode = profile.postalCode
        country = profile.country
    }

    func toUserProfile() -> UserProfile {
        UserProfile(
            firstName: firstName,
            lastName: lastName,
            company: company,
            taxNumber: taxNumber,
            phone: phone,
            addressLine1: addressLine1,
            addressLine2: addressLine2,
            city: city,
            postalCode: postalCode,
            country: country
        )
    }
}

/// Form data for password change.
public struct PasswordFormData: Equatable, Sendable {
    public var currentPassword: String = ""
    public var newPassword: String = ""
    public var confirmPassword: String = ""

    public init() {}
}

/// Drives the profile edit form. Owns loading/saving/error state and validation.
/// Views are thin — they bind to @Published properties (SRP).
@MainActor
public final class ProfileViewModel: ObservableObject {
    @Published public var formData = ProfileFormData()
    @Published public var passwordData = PasswordFormData()
    @Published public var isLoading = false
    @Published public var isSaving = false
    @Published public var errorMessage: String?
    @Published public var successMessage: String?
    @Published public var passwordError: String?
    @Published public var passwordSuccess: String?

    private let service: ProfileService

    public init(service: ProfileService) {
        self.service = service
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let profile = try await service.fetchProfile()
            formData = ProfileFormData(from: profile)
        } catch {
            errorMessage = (error as? APIError)?.message ?? "Failed to load profile"
        }
        isLoading = false
    }

    public func save() async {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        do {
            let updated = try await service.updateDetails(formData.toUserProfile())
            formData = ProfileFormData(from: updated)
            successMessage = "Profile updated successfully"
        } catch {
            errorMessage = (error as? APIError)?.message ?? "Failed to save profile"
            successMessage = nil
        }
        isSaving = false
    }

    public func changePassword() async {
        passwordError = nil
        passwordSuccess = nil

        // Validation
        if passwordData.currentPassword.isEmpty ||
           passwordData.newPassword.isEmpty ||
           passwordData.confirmPassword.isEmpty {
            passwordError = "All password fields are required"
            return
        }
        if passwordData.newPassword != passwordData.confirmPassword {
            passwordError = "New passwords do not match"
            return
        }
        if passwordData.newPassword.count < 8 {
            passwordError = "New password must be at least 8 characters"
            return
        }

        do {
            try await service.changePassword(
                current: passwordData.currentPassword,
                new: passwordData.newPassword)
            passwordData = PasswordFormData()
            passwordSuccess = "Password changed successfully"
        } catch {
            passwordError = (error as? APIError)?.message ?? "Failed to change password"
        }
    }
}
