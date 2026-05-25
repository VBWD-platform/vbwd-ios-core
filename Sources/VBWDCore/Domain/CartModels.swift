/// Generic cart item. Port of the web `ICartItem` (fe-core `cart.ts`).
/// The `type` discriminator is an opaque string — core never switches on it.
/// Plugins set domain-specific types (`"token_bundle"`, `"subscription"`,
/// `"shop_product"`) so the checkout source registry can match items to the
/// correct handler.
public struct CartItem: Identifiable, Equatable, Sendable {
    public let type: String
    public let id: String
    public let name: String
    public let price: Double
    public var quantity: Int
    public let currency: String
    public let metadata: [String: String]

    public init(type: String,
                id: String,
                name: String,
                price: Double,
                quantity: Int = 1,
                currency: String = "USD",
                metadata: [String: String] = [:]) {
        self.type = type
        self.id = id
        self.name = name
        self.price = price
        self.quantity = quantity
        self.currency = currency
        self.metadata = metadata
    }
}

/// Context passed when navigating to checkout. On the web this comes from
/// URL query params (`?tarif_plan_id=pro&source=shop`). On iOS it's a struct
/// passed programmatically, avoiding query-param parsing in the route system.
public struct CheckoutContext: Sendable {
    public let source: String?
    public let planSlug: String?
    public let isCart: Bool
    public let extras: [String: String]

    public init(source: String? = nil,
                planSlug: String? = nil,
                isCart: Bool = true,
                extras: [String: String] = [:]) {
        self.source = source
        self.planSlug = planSlug
        self.isCart = isCart
        self.extras = extras
    }
}

// MARK: - TokenBundle → CartItem

public extension TokenBundle {
    /// Convert a token bundle to a generic cart item.
    func toCartItem() -> CartItem {
        CartItem(
            type: "token_bundle",
            id: id,
            name: name,
            price: Double(price) ?? 0,
            quantity: 1,
            currency: currency ?? "USD",
            metadata: [
                "token_amount": "\(tokenAmount)",
                "slug": slug ?? "",
            ]
        )
    }
}
