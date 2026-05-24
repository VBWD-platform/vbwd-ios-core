/// Configurable store & checkout endpoints (same pattern as `AuthEndpoints`,
/// `ProfileEndpoints`, `DashboardEndpoints`).
public struct StoreEndpoints: Equatable, Sendable {
    public var tokenBundles: String
    public var paymentMethods: String
    public var checkout: String

    public init(tokenBundles: String = "/token-bundles",
                paymentMethods: String = "/settings/payment-methods",
                checkout: String = "/user/checkout") {
        self.tokenBundles = tokenBundles
        self.paymentMethods = paymentMethods
        self.checkout = checkout
    }
}
