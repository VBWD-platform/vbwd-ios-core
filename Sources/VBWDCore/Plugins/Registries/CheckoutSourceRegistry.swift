import SwiftUI

/// Plugin contract for checkout sources. Port of the web
/// `CheckoutSource` interface from `checkoutSourceRegistry.ts`.
/// Each plugin provides one implementation (subscription, shop, etc.).
/// Core discovers the matching source via the `CheckoutSourceRegistry`
/// and delegates all domain logic to it.
@MainActor
public protocol CheckoutSource: AnyObject {
    /// Unique identifier (e.g. `"token_bundle"`, `"subscription"`, `"shop"`).
    var id: String { get }

    /// Higher priority wins when multiple sources match. Default is 0.
    var priority: Int { get }

    /// Does this source handle the given checkout context?
    func matches(_ ctx: CheckoutContext) -> Bool

    /// Load items for this checkout context (e.g. fetch plan, read cart).
    func load(_ ctx: CheckoutContext) async throws

    /// Project plugin-internal state into generic cart items for the
    /// checkout UI to render.
    func lineItems() -> [CartItem]

    /// Computed order total from the loaded items.
    func orderTotal() -> Double

    /// Submit the checkout. The source builds and posts its own request body
    /// (e.g. `POST /user/checkout` with `token_bundle_ids` or
    /// `POST /shop/cart/checkout` with product items). Returns the standard
    /// `CheckoutResult` wrapping the backend invoice.
    func submit(paymentMethodCode: String?) async throws -> CheckoutResult

    /// Clear loaded state so the source can be reused.
    func reset()

    /// Optional custom summary view. If non-nil, the checkout page renders
    /// this instead of the generic line-item list.
    var summaryComponent: ComponentFactory? { get }
}

/// Default implementations for optional members.
public extension CheckoutSource {
    var priority: Int { 0 }
    var summaryComponent: ComponentFactory? { nil }
}

/// Registry of checkout sources. Port of the web `checkoutSourceRegistry`.
/// `find()` returns the highest-priority source whose `matches()` is true.
@MainActor
public final class CheckoutSourceRegistry {
    private var sources: [CheckoutSource] = []

    public init() {}

    public func register(_ source: CheckoutSource) {
        // Replace if same ID already registered
        sources.removeAll { $0.id == source.id }
        sources.append(source)
    }

    public func unregister(id: String) {
        sources.removeAll { $0.id == id }
    }

    /// Find the highest-priority source that matches the context.
    public func find(_ ctx: CheckoutContext) -> CheckoutSource? {
        sources
            .filter { $0.matches(ctx) }
            .sorted { $0.priority > $1.priority }
            .first
    }

    public func get(id: String) -> CheckoutSource? {
        sources.first { $0.id == id }
    }

    public var all: [CheckoutSource] { sources }
}
