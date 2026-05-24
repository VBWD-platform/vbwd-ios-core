import Foundation

/// User profile detail fields. Matches the backend `GET /user/profile`
/// `details` object shape (snake_case JSON keys).
public struct UserProfile: Codable, Equatable, Sendable {
    public var firstName: String
    public var lastName: String
    public var company: String
    public var taxNumber: String
    public var phone: String
    public var addressLine1: String
    public var addressLine2: String
    public var city: String
    public var postalCode: String
    public var country: String

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case company
        case taxNumber = "tax_number"
        case phone
        case addressLine1 = "address_line_1"
        case addressLine2 = "address_line_2"
        case city
        case postalCode = "postal_code"
        case country
    }

    public init(firstName: String = "",
                lastName: String = "",
                company: String = "",
                taxNumber: String = "",
                phone: String = "",
                addressLine1: String = "",
                addressLine2: String = "",
                city: String = "",
                postalCode: String = "",
                country: String = "") {
        self.firstName = firstName
        self.lastName = lastName
        self.company = company
        self.taxNumber = taxNumber
        self.phone = phone
        self.addressLine1 = addressLine1
        self.addressLine2 = addressLine2
        self.city = city
        self.postalCode = postalCode
        self.country = country
    }

    /// The backend may return `null` for any detail field (e.g. a freshly
    /// created user has no `tax_number`). Decode nulls as empty strings so
    /// the rest of the app can bind to plain `String` properties.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        firstName    = try c.decodeIfPresent(String.self, forKey: .firstName)    ?? ""
        lastName     = try c.decodeIfPresent(String.self, forKey: .lastName)     ?? ""
        company      = try c.decodeIfPresent(String.self, forKey: .company)      ?? ""
        taxNumber    = try c.decodeIfPresent(String.self, forKey: .taxNumber)    ?? ""
        phone        = try c.decodeIfPresent(String.self, forKey: .phone)        ?? ""
        addressLine1 = try c.decodeIfPresent(String.self, forKey: .addressLine1) ?? ""
        addressLine2 = try c.decodeIfPresent(String.self, forKey: .addressLine2) ?? ""
        city         = try c.decodeIfPresent(String.self, forKey: .city)         ?? ""
        postalCode   = try c.decodeIfPresent(String.self, forKey: .postalCode)   ?? ""
        country      = try c.decodeIfPresent(String.self, forKey: .country)      ?? ""
    }
}

/// Response shape for `GET /user/profile`.
public struct ProfileResponse: Codable, Equatable, Sendable {
    public let user: ProfileResponseUser?
    public let details: UserProfile?
}

/// Minimal user info returned within the profile response.
public struct ProfileResponseUser: Codable, Equatable, Sendable {
    public let id: String
    public let email: String
}

/// Response shape for `PUT /user/details`.
public struct UpdateDetailsResponse: Codable, Equatable, Sendable {
    public let details: UserProfile?
}

/// Response shape for `POST /user/change-password`.
public struct ChangePasswordResponse: Codable, Equatable, Sendable {
    public let success: Bool?
    public let error: String?
}
