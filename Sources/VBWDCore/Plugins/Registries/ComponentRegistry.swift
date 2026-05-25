import SwiftUI

/// Lazy view factory a plugin registers (web `ComponentDefinition`).
public typealias ComponentFactory = () -> AnyView

/// Enum returned by a payment action handler to tell the checkout what to do
/// after `POST /user/checkout` succeeds.
public enum PaymentAction: Sendable {
    /// Go straight to the confirmation page (e.g. invoice payment).
    case showConfirmation
    /// Open an external URL for payment (e.g. Stripe Checkout session URL).
    /// The checkout flow will open this URL in-app and show the confirmation
    /// page when the user returns.
    case openURL(URL, sessionId: String?)
}

/// Async closure a payment plugin registers. Called after checkout creates
/// the invoice; receives the invoice ID and returns what the checkout should
/// do next. Mirrors the web's post-submit redirect logic in
/// `PublicCheckoutView.vue`.
public typealias PaymentActionHandler = @Sendable (String) async throws -> PaymentAction

/// Named component registry. Port of `addComponent`/`removeComponent`/
/// `getComponents`. Owns the single `Dashboard*` filter the dashboard reuses
/// (DRY — web `Dashboard.vue` `name.startsWith('Dashboard')`).
public final class ComponentRegistry {
    private var components: [String: ComponentFactory] = [:]
    private var order: [String] = []
    private var paymentHandlers: [String: PaymentActionHandler] = [:]

    public init() {}

    public func add(_ name: String, _ factory: @escaping ComponentFactory) {
        if components[name] == nil { order.append(name) }
        components[name] = factory
    }

    public func remove(_ name: String) {
        components[name] = nil
        order.removeAll { $0 == name }
    }

    public func get(_ name: String) -> ComponentFactory? { components[name] }

    public func all() -> [String: ComponentFactory] { components }

    /// Names in registration order (deterministic widget ordering).
    public func names() -> [String] { order }

    /// The web dashboard-widget convention: components named `Dashboard*`,
    /// in registration order.
    public func dashboardComponents() -> [(name: String, factory: ComponentFactory)] {
        order.filter { $0.hasPrefix("Dashboard") }
             .compactMap { n in components[n].map { (n, $0) } }
    }

    /// Profile extension convention: components named `Profile*`,
    /// in registration order. Plugins register these to add sections to the
    /// profile screen (mirrors the `Dashboard*` pattern).
    public func profileComponents() -> [(name: String, factory: ComponentFactory)] {
        order.filter { $0.hasPrefix("Profile") }
             .compactMap { n in components[n].map { (n, $0) } }
    }

    /// Checkout extension convention: components named `Checkout*`,
    /// in registration order. Plugins register these to inject sections into
    /// the checkout screen (e.g. discount codes, shipping, insurance).
    public func checkoutComponents() -> [(name: String, factory: ComponentFactory)] {
        order.filter { $0.hasPrefix("Checkout") }
             .compactMap { n in components[n].map { (n, $0) } }
    }

    /// Payment method convention: components named `PaymentMethod*` declare
    /// which payment method codes have an installed plugin. The suffix after
    /// `PaymentMethod` is lower-cased and matched against `PaymentMethod.code`
    /// from the backend. E.g. `PaymentMethodStripe` → code `"stripe"`.
    public func supportedPaymentMethodCodes() -> Set<String> {
        Set(
            order.filter { $0.hasPrefix("PaymentMethod") }
                 .map { String($0.dropFirst("PaymentMethod".count)).lowercased() }
                 .filter { !$0.isEmpty }
        )
    }

    /// Returns the detail view factory for a payment method code, if a plugin
    /// registered one. Looks up `PaymentMethod{Code}` (capitalised first letter).
    /// E.g. code `"stripe"` → looks up `"PaymentMethodStripe"`.
    public func paymentMethodDetail(for code: String) -> ComponentFactory? {
        let capitalized = code.prefix(1).uppercased() + code.dropFirst()
        return components["PaymentMethod\(capitalized)"]
    }

    // MARK: - Payment Action Handlers

    /// Register a post-checkout handler for a payment method code. The handler
    /// is called after `POST /user/checkout` succeeds and decides what happens
    /// next (e.g. open Stripe URL, or go straight to confirmation).
    public func addPaymentAction(_ code: String, _ handler: @escaping PaymentActionHandler) {
        paymentHandlers[code.lowercased()] = handler
    }

    /// Look up the payment action handler for a method code. Returns nil for
    /// methods that go straight to confirmation (e.g. invoice).
    public func paymentAction(for code: String) -> PaymentActionHandler? {
        paymentHandlers[code.lowercased()]
    }
}
