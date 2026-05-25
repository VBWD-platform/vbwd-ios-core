import Foundation

/// The checkout flow's current phase. Drives CheckoutView transitions:
/// `.form` → `.processingPayment` → `.confirmation`.
public enum CheckoutPhase: Equatable {
    case form
    case processingPayment(URL, sessionId: String?)
    case confirmation(CheckoutResult)
}

/// Checkout screen logic. Fetches payment methods from the backend, renders an
/// order summary of `CheckoutItem`s, and submits via `POST /user/checkout`.
/// After the order is created, it asks the selected payment plugin what to do
/// next (redirect to Stripe, or go straight to confirmation for invoice).
@MainActor
public final class CheckoutViewModel: ObservableObject {
    @Published public private(set) var isLoading = false
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var paymentMethods: [PaymentMethod] = []
    @Published public var selectedMethodId: String?
    @Published public private(set) var checkoutResult: CheckoutResult?
    @Published public private(set) var phase: CheckoutPhase = .form
    @Published public private(set) var errorMessage: String?

    public let items: [any CheckoutItem]
    private let api: APIClient
    private let endpoints: StoreEndpoints
    private let components: ComponentRegistry?

    public init(api: APIClient,
                items: [any CheckoutItem],
                endpoints: StoreEndpoints = StoreEndpoints(),
                components: ComponentRegistry? = nil) {
        self.api = api
        self.items = items
        self.endpoints = endpoints
        self.components = components
    }

    // MARK: - Computed

    /// Plugin-injected checkout sections (`Checkout*` convention).
    public var checkoutComponents: [(name: String, factory: ComponentFactory)] {
        components?.checkoutComponents() ?? []
    }

    /// Returns the plugin-provided detail view for a payment method code,
    /// or nil if the plugin didn't register one.
    public func paymentMethodDetail(for code: String) -> ComponentFactory? {
        components?.paymentMethodDetail(for: code)
    }

    /// Summed order total from all items.
    public var orderTotal: Double {
        items.reduce(0) { sum, item in
            sum + (Double(item.checkoutItemPrice) ?? 0) * Double(item.checkoutItemQuantity)
        }
    }

    /// Currency from the first item (all items expected same currency).
    public var currency: String {
        items.first?.checkoutItemCurrency ?? "USD"
    }

    public var canSubmit: Bool {
        selectedMethodId != nil && !isSubmitting && !items.isEmpty
    }

    // MARK: - Actions

    public func loadPaymentMethods() async {
        isLoading = true
        let r: PaymentMethodsResponse? = try? await api.get(endpoints.paymentMethods)
        let all = r?.methods ?? []
        // Only show methods that have a corresponding iOS plugin installed.
        let supported = components?.supportedPaymentMethodCodes()
        if let supported, !supported.isEmpty {
            paymentMethods = all.filter { supported.contains($0.code) }
        } else {
            paymentMethods = all
        }
        isLoading = false
    }

    /// Creates the order via `POST /user/checkout`, then delegates to the
    /// plugin's payment action handler. Mirrors the web `PublicCheckoutView`
    /// post-submit watcher that routes to `/pay/stripe` or `/checkout/confirmation`.
    public func submit() async {
        guard let methodCode = selectedMethodId else { return }

        isSubmitting = true
        errorMessage = nil

        let bundleIds = items.map(\.checkoutItemId)
        let request = CheckoutRequest(
            tokenBundleIds: bundleIds,
            currency: currency,
            paymentMethodCode: methodCode
        )

        do {
            let result: CheckoutResult = try await api.post(
                endpoints.checkout, body: request)
            checkoutResult = result

            guard let invoiceId = result.invoiceId else {
                phase = .confirmation(result)
                isSubmitting = false
                return
            }

            // Ask the payment plugin what to do next
            if let handler = components?.paymentAction(for: methodCode) {
                let action = try await handler(invoiceId)
                switch action {
                case .showConfirmation:
                    phase = .confirmation(result)
                case let .openURL(url, sessionId):
                    phase = .processingPayment(url, sessionId: sessionId)
                }
            } else {
                // No handler registered → go straight to confirmation (invoice)
                phase = .confirmation(result)
            }
        } catch {
            errorMessage = (error as? APIError)?.message ?? error.localizedDescription
        }

        isSubmitting = false
    }

    /// Called when the user returns from an external payment page (e.g. Stripe).
    public func completePayment() {
        if let result = checkoutResult {
            phase = .confirmation(result)
        }
    }
}
