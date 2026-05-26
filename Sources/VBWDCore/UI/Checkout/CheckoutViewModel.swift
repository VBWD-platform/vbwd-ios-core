import Foundation

/// The checkout flow's current phase. Drives CheckoutView transitions:
/// `.form` → `.processingPayment` → `.confirmation`.
public enum CheckoutPhase: Equatable {
    case form
    case processingPayment(URL, sessionId: String?)
    case confirmation(CheckoutResult)
}

/// Checkout orchestrator. Finds the matching `CheckoutSource` for the given
/// context, delegates `load()`/`submit()` to it, and manages payment method
/// selection + phase transitions. Mirrors the web `checkout.ts` store —
/// core never names a domain, only delegates.
@MainActor
public final class CheckoutViewModel: ObservableObject {
    @Published public private(set) var isLoading = false
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var paymentMethods: [PaymentMethod] = []
    @Published public var selectedMethodId: String?
    @Published public private(set) var checkoutResult: CheckoutResult?
    @Published public private(set) var phase: CheckoutPhase = .form
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var lineItems: [CartItem] = []

    public private(set) var activeSource: CheckoutSource?

    private let api: APIClient
    private let context: CheckoutContext
    private let cart: Cart
    private let checkoutSources: CheckoutSourceRegistry
    private let endpoints: StoreEndpoints
    private let components: ComponentRegistry?
    private let events: EventBus?

    public init(api: APIClient,
                context: CheckoutContext,
                cart: Cart,
                checkoutSources: CheckoutSourceRegistry,
                endpoints: StoreEndpoints = StoreEndpoints(),
                components: ComponentRegistry? = nil,
                events: EventBus? = nil) {
        self.api = api
        self.context = context
        self.cart = cart
        self.checkoutSources = checkoutSources
        self.endpoints = endpoints
        self.components = components
        self.events = events
    }

    // MARK: - Computed

    /// Plugin-injected checkout sections (`Checkout*` convention).
    public var checkoutComponents: [(name: String, factory: ComponentFactory)] {
        components?.checkoutComponents() ?? []
    }

    /// Returns the plugin-provided detail view for a payment method code.
    public func paymentMethodDetail(for code: String) -> ComponentFactory? {
        components?.paymentMethodDetail(for: code)
    }

    /// Order total from the active source, or summed from lineItems.
    /// When showing full cart (no specific source), use lineItems sum.
    public var orderTotal: Double {
        if context.isCart && context.source == nil {
            return lineItems.reduce(0) { $0 + $1.price * Double($1.quantity) }
        }
        return activeSource?.orderTotal() ?? lineItems.reduce(0) { $0 + $1.price * Double($1.quantity) }
    }

    /// Currency from the first line item.
    public var currency: String {
        lineItems.first?.currency ?? "USD"
    }

    public var canSubmit: Bool {
        selectedMethodId != nil && !isSubmitting && !lineItems.isEmpty
    }

    // MARK: - Actions

    /// Find the matching checkout source, load its items, and fetch payment
    /// methods. Called by CheckoutView in `.task`.
    public func loadForContext() async {
        isLoading = true
        events?.emit(AppEvents.checkoutStarted)

        // Find the checkout source that handles this context
        let source = checkoutSources.find(context)
        activeSource = source

        // When opened from the cart button (isCart + no specific source),
        // show ALL cart items instead of only one source's items.
        // Still call source.load() so it populates its internal state
        // (e.g. loadedItems for token_bundle_ids) needed by submit().
        if context.isCart && context.source == nil {
            if let source {
                try? await source.load(context)
            }
            lineItems = cart.items
        } else if let source {
            do {
                try await source.load(context)
                lineItems = source.lineItems()
            } catch {
                errorMessage = (error as? APIError)?.message ?? error.localizedDescription
            }
        } else {
            // Fallback: read cart items directly
            lineItems = cart.items
        }

        // Load payment methods
        await loadPaymentMethods()
        isLoading = false
    }

    /// Whether this is a zero-total checkout (e.g. free trial subscription).
    public var isZeroTotal: Bool { orderTotal <= 0 }

    /// Whether the cart contains items with different billing intervals
    /// (e.g. monthly subscription + yearly add-on). Stripe rejects mixed intervals.
    public private(set) var hasMixedBillingIntervals = false

    /// Fetches payment methods and filters by installed plugins.
    /// When the order total is zero, only "invoice" is offered and auto-selected.
    /// When items have mixed billing intervals, Stripe is excluded.
    public func loadPaymentMethods() async {
        let r: PaymentMethodsResponse? = try? await api.get(endpoints.paymentMethods)
        let all = r?.methods ?? []

        if isZeroTotal {
            // Zero-total orders: only allow invoice payment
            paymentMethods = all.filter { $0.code.lowercased() == "invoice" }
            if let invoice = paymentMethods.first {
                selectedMethodId = invoice.code
            }
            return
        }

        // Detect mixed billing intervals in cart items
        let billingPeriods = Set(
            lineItems.compactMap { $0.metadata["billing_period"] }
                     .filter { !$0.isEmpty }
        )
        hasMixedBillingIntervals = billingPeriods.count > 1

        let supported = components?.supportedPaymentMethodCodes()
        var filtered: [PaymentMethod]
        if let supported, !supported.isEmpty {
            filtered = all.filter { supported.contains($0.code) }
        } else {
            filtered = all
        }

        // Stripe does not support mixed billing intervals — exclude it
        if hasMixedBillingIntervals {
            filtered = filtered.filter { $0.code.lowercased() != "stripe" }
        }

        paymentMethods = filtered
    }

    /// Delegates submit to the active checkout source, then routes to
    /// the payment plugin's action handler. Mirrors the web `PublicCheckoutView`
    /// post-submit watcher.
    public func submit() async {
        guard let methodCode = selectedMethodId else { return }
        guard let source = activeSource else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            let result = try await source.submit(paymentMethodCode: methodCode)
            checkoutResult = result

            guard let invoiceId = result.invoiceId else {
                finishCheckout(with: result)
                isSubmitting = false
                return
            }

            // Ask the payment plugin what to do next
            if let handler = components?.paymentAction(for: methodCode) {
                let action = try await handler(invoiceId)
                switch action {
                case .showConfirmation:
                    // Instant payment (e.g. token balance) succeeded — mark as paid
                    finishCheckout(with: result.withStatus("paid"))
                case let .openURL(url, sessionId):
                    phase = .processingPayment(url, sessionId: sessionId)
                }
            } else {
                // No handler → straight to confirmation (invoice)
                finishCheckout(with: result)
            }
        } catch {
            errorMessage = (error as? APIError)?.message ?? error.localizedDescription
            events?.emit(AppEvents.checkoutFailed)
        }

        isSubmitting = false
    }

    /// Called when the user returns from an external payment page (e.g. Stripe).
    /// Polls the payment status if a session ID is available, then transitions
    /// to confirmation.
    public func completePayment() {
        if case let .processingPayment(_, sessionId) = phase,
           let sessionId, !sessionId.isEmpty {
            Task {
                await pollPaymentStatus(sessionId: sessionId)
            }
        } else if let result = checkoutResult {
            finishCheckout(with: result)
        }
    }

    /// Called when `ASWebAuthenticationSession` returns a callback URL from the
    /// payment provider (e.g. `vbwd://stripe-callback/success?session_id=cs_...`).
    /// Extracts the `session_id` query parameter and polls payment status.
    /// When the user cancels (nil URL), returns to the form immediately.
    public func completePayment(callbackURL: URL?) {
        guard let callbackURL else {
            // User closed the payment browser — return to form immediately
            errorMessage = "Payment was cancelled."
            phase = .form
            isSubmitting = false
            return
        }

        // Detect cancel path in callback URL (e.g. vbwd://stripe-callback/cancel)
        let path = callbackURL.path.lowercased()
        if path.contains("cancel") {
            errorMessage = "Payment was cancelled."
            phase = .form
            isSubmitting = false
            return
        }

        if let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
           let sessionId = components.queryItems?.first(where: { $0.name == "session_id" })?.value,
           !sessionId.isEmpty {
            Task {
                await pollPaymentStatus(sessionId: sessionId)
            }
        } else {
            // Callback URL present but no session_id — fall back to polling
            completePayment()
        }
    }

    // MARK: - Checkout Completion

    /// Transitions to confirmation, clears the cart, and emits the
    /// `checkoutCompleted` event. Call this instead of setting `phase`
    /// directly so the cart is always cleaned up.
    private func finishCheckout(with result: CheckoutResult) {
        phase = .confirmation(result)
        cart.clear()
        events?.emit(AppEvents.checkoutCompleted)
    }

    // MARK: - Payment Status Polling

    /// Poll the payment provider's status endpoint until we get a terminal
    /// state. Matches the web `usePaymentStatus` (2s interval, max 10 attempts).
    private func pollPaymentStatus(sessionId: String) async {
        struct StatusResponse: Codable {
            let status: String?
            let invoiceId: String?
            enum CodingKeys: String, CodingKey {
                case status
                case invoiceId = "invoice_id"
            }
        }

        let maxAttempts = 10
        let interval: UInt64 = 2_000_000_000

        for _ in 0..<maxAttempts {
            let resp: StatusResponse? = try? await api.get(
                "/plugins/stripe/session-status/\(sessionId)")

            if let status = resp?.status?.lowercased() {
                if status == "paid" || status == "complete" {
                    if var result = checkoutResult, let invoice = result.invoice {
                        let updated = CheckoutInvoice(
                            id: invoice.id,
                            invoiceNumber: invoice.invoiceNumber,
                            amount: invoice.amount,
                            totalAmount: invoice.totalAmount,
                            currency: invoice.currency,
                            status: "paid",
                            paymentMethod: invoice.paymentMethod,
                            lineItems: invoice.lineItems)
                        result = CheckoutResult(invoice: updated, message: result.message)
                        finishCheckout(with: result)
                    } else {
                        finishCheckout(with:
                            checkoutResult ?? CheckoutResult(invoice: nil, message: "Payment successful"))
                    }
                    events?.emit(AppEvents.paymentSucceeded)
                    return
                } else if status == "failed" || status == "expired" {
                    errorMessage = "Payment failed. Please try again."
                    phase = .form
                    events?.emit(AppEvents.paymentFailed)
                    return
                }
            }

            try? await Task.sleep(nanoseconds: interval)
        }

        // Timeout — show confirmation with current (pending) status
        if let result = checkoutResult {
            finishCheckout(with: result)
        }
    }
}
