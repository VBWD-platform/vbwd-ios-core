import Foundation

/// Built-in checkout source for token bundles. This is the only domain-
/// specific checkout source in VBWDCore (token bundles are a core backend
/// feature, not a plugin). Plugin checkout sources (subscription, shop)
/// register themselves via `PlatformSDK.addCheckoutSource()`.
///
/// Mirrors the web subscription plugin's checkout source, but scoped to
/// token bundles only: reads `token_bundle` items from the `Cart`, submits
/// to `POST /user/checkout` with `token_bundle_ids`, and returns the
/// standard `CheckoutResult`.
@MainActor
public final class TokenBundleCheckoutSource: CheckoutSource {
    public let id = "token_bundle"
    public let priority = 0

    private let api: APIClient
    private let cart: Cart
    private let endpoints: StoreEndpoints
    private var loadedItems: [CartItem] = []

    public init(api: APIClient, cart: Cart, endpoints: StoreEndpoints = StoreEndpoints()) {
        self.api = api
        self.cart = cart
        self.endpoints = endpoints
    }

    // MARK: - CheckoutSource

    public func matches(_ ctx: CheckoutContext) -> Bool {
        // Match when: no explicit source hint (default), or source is "token_bundle",
        // or the cart has token_bundle items.
        if let source = ctx.source {
            return source == "token_bundle"
        }
        return !cart.items(ofType: "token_bundle").isEmpty
    }

    public func load(_ ctx: CheckoutContext) async throws {
        loadedItems = cart.items(ofType: "token_bundle")
    }

    public func lineItems() -> [CartItem] {
        loadedItems
    }

    public func orderTotal() -> Double {
        loadedItems.reduce(0) { $0 + $1.price * Double($1.quantity) }
    }

    public func submit(paymentMethodCode: String?) async throws -> CheckoutResult {
        let bundleIds = loadedItems.map(\.id)
        let currency = loadedItems.first?.currency ?? "USD"
        // Include add-ons from cart so mixed-cart checkout works
        let addOnIds = cart.items(ofType: "add_on").map(\.id)

        let request = TokenBundleCheckoutRequest(
            tokenBundleIds: bundleIds,
            addOnIds: addOnIds,
            currency: currency,
            paymentMethodCode: paymentMethodCode ?? ""
        )

        let result: CheckoutResult = try await api.post(endpoints.checkout, body: request)
        return result
    }

    public func reset() {
        loadedItems = []
    }

    public var summaryComponent: ComponentFactory? { nil }
}

/// Request body for `POST /user/checkout` with token bundle IDs.
/// Source-owned — not exposed as a public model. Other checkout sources
/// (subscription, shop) build their own request bodies.
struct TokenBundleCheckoutRequest: Encodable, Sendable {
    let tokenBundleIds: [String]
    let addOnIds: [String]
    let currency: String
    let paymentMethodCode: String

    enum CodingKeys: String, CodingKey {
        case tokenBundleIds = "token_bundle_ids"
        case addOnIds = "add_on_ids"
        case currency
        case paymentMethodCode = "payment_method_code"
    }
}
