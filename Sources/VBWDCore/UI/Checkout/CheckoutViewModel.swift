import Foundation

/// Checkout screen logic. Fetches payment methods from the backend, renders an
/// order summary of `CheckoutItem`s, and submits via `POST /user/checkout`.
/// Plugin-contributed `Checkout*` components (discount coupon, shipping, etc.)
/// are discovered through `ComponentRegistry` — same convention as `Dashboard*`
/// and `Profile*`.
@MainActor
public final class CheckoutViewModel: ObservableObject {
    @Published public private(set) var isLoading = false
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var paymentMethods: [PaymentMethod] = []
    @Published public var selectedMethodId: String?
    @Published public private(set) var checkoutResult: CheckoutResult?
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
        paymentMethods = r?.paymentMethods ?? []
        isLoading = false
    }

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
        } catch {
            errorMessage = (error as? APIError)?.message ?? error.localizedDescription
        }

        isSubmitting = false
    }
}
