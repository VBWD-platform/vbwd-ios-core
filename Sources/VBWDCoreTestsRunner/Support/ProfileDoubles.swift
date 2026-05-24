import Foundation
import VBWDCore

/// Scriptable `ProfileService` double for ViewModel tests.
final class SpyProfileService: ProfileService, @unchecked Sendable {
    var fetchResult: Result<UserProfile, Error> = .success(ProfileFixtures.fullProfile)
    var updateResult: Result<UserProfile, Error> = .success(ProfileFixtures.fullProfile)
    var changePasswordResult: Result<Void, Error> = .success(())

    private(set) var fetchCalled = false
    private(set) var updateCalledWith: UserProfile?
    private(set) var changePasswordCalledWith: (current: String, new: String)?

    func fetchProfile() async throws -> UserProfile {
        fetchCalled = true
        return try fetchResult.get()
    }

    func updateDetails(_ profile: UserProfile) async throws -> UserProfile {
        updateCalledWith = profile
        return try updateResult.get()
    }

    func changePassword(current: String, new newPassword: String) async throws {
        changePasswordCalledWith = (current, newPassword)
        try changePasswordResult.get()
    }
}

enum ProfileFixtures {
    static let fullProfile = UserProfile(
        firstName: "Jane",
        lastName: "Doe",
        company: "Acme Inc.",
        taxNumber: "DE123456789",
        phone: "+49 123 456 7890",
        addressLine1: "123 Main Street",
        addressLine2: "Apt 4B",
        city: "Berlin",
        postalCode: "10115",
        country: "Germany"
    )

    static let profileResponseJSON = """
    {
        "user": {"id": "1", "email": "jane@example.com"},
        "details": {
            "first_name": "Jane",
            "last_name": "Doe",
            "company": "Acme Inc.",
            "tax_number": "DE123456789",
            "phone": "+49 123 456 7890",
            "address_line_1": "123 Main Street",
            "address_line_2": "Apt 4B",
            "city": "Berlin",
            "postal_code": "10115",
            "country": "Germany"
        }
    }
    """.data(using: .utf8)!

    static let updateResponseJSON = """
    {
        "details": {
            "first_name": "Jane",
            "last_name": "Doe",
            "company": "Acme Inc.",
            "tax_number": "DE123456789",
            "phone": "+49 123 456 7890",
            "address_line_1": "123 Main Street",
            "address_line_2": "Apt 4B",
            "city": "Berlin",
            "postal_code": "10115",
            "country": "Germany"
        }
    }
    """.data(using: .utf8)!

    static let changePasswordSuccessJSON = """
    {"success": true}
    """.data(using: .utf8)!
}
