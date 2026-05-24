/// Store & checkout models. Port of the web `TokenBundle` (backend model) and
/// `PaymentMethod` (settings endpoint). `CheckoutItem` is the protocol that
/// makes the checkout screen source-agnostic (token bundles today, subscription
/// plans tomorrow).

// MARK: - Token Bundles

public struct TokenBundle: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let slug: String?
    public let description: String?
    public let tokenAmount: Int
    public let price: String        // "29.99" — string from backend
    public let currency: String?    // ISO 4217, e.g. "USD" — absent from some backends
    public let isActive: Bool?
    public let sortOrder: Int?      // backend uses "sort_order"

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description, price, currency
        case tokenAmount = "token_amount"
        case isActive = "is_active"
        case sortOrder = "sort_order"
    }
}

struct TokenBundlesResponse: Codable {
    let bundles: [TokenBundle]?
}

// MARK: - Payment Methods

public struct PaymentMethod: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let code: String
    public let name: String
    public let icon: String?
    public let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id, code, name, icon
        case isActive = "is_active"
    }
}

struct PaymentMethodsResponse: Codable {
    let paymentMethods: [PaymentMethod]?

    enum CodingKeys: String, CodingKey {
        case paymentMethods = "payment_methods"
    }
}

// MARK: - Checkout Item Protocol

/// Anything purchasable. The checkout screen renders items through this
/// protocol so it stays source-agnostic (OCP — token bundles, subscription
/// plans, add-ons can all conform without modifying checkout).
public protocol CheckoutItem: Sendable {
    var checkoutItemId: String { get }
    var checkoutItemName: String { get }
    var checkoutItemPrice: String { get }
    var checkoutItemCurrency: String { get }
    var checkoutItemQuantity: Int { get }
}

extension TokenBundle: CheckoutItem {
    public var checkoutItemId: String { id }
    public var checkoutItemName: String { name }
    public var checkoutItemPrice: String { price }
    public var checkoutItemCurrency: String { currency ?? "USD" }
    public var checkoutItemQuantity: Int { 1 }
}

// MARK: - Checkout Request / Result

/// Payload sent to `POST /user/checkout`. Mirrors the web
/// `CheckoutRequestedEvent` fields (plan, bundles, add-ons, payment method).
public struct CheckoutRequest: Encodable, Sendable {
    public let tokenBundleIds: [String]?
    public let currency: String
    public let paymentMethodCode: String

    public init(tokenBundleIds: [String]? = nil,
                currency: String = "USD",
                paymentMethodCode: String) {
        self.tokenBundleIds = tokenBundleIds
        self.currency = currency
        self.paymentMethodCode = paymentMethodCode
    }

    enum CodingKeys: String, CodingKey {
        case currency
        case tokenBundleIds = "token_bundle_ids"
        case paymentMethodCode = "payment_method_code"
    }
}

/// Response from `POST /user/checkout`.
public struct CheckoutResult: Codable, Sendable {
    public let invoiceId: String?
    public let status: String?

    enum CodingKeys: String, CodingKey {
        case invoiceId = "invoice_id"
        case status
    }
}
