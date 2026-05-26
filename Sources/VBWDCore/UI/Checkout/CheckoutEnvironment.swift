import SwiftUI

/// Checkout context passed to payment method detail views via the
/// SwiftUI environment. Allows plugin-provided payment detail components
/// (e.g. token balance quote) to read the current order amount and currency
/// without needing a direct reference to `CheckoutViewModel`.
public struct CheckoutInfo: Equatable, Sendable {
    public let amount: Double
    public let currency: String

    public init(amount: Double = 0, currency: String = "USD") {
        self.amount = amount
        self.currency = currency
    }
}

private struct CheckoutInfoKey: EnvironmentKey {
    static let defaultValue = CheckoutInfo()
}

public extension EnvironmentValues {
    var checkoutInfo: CheckoutInfo {
        get { self[CheckoutInfoKey.self] }
        set { self[CheckoutInfoKey.self] = newValue }
    }
}

// MARK: - Token Pay Button Label

/// Preference key for payment method plugins to override the pay button label.
/// When a plugin sets this (e.g. "Pay 600 tokens"), the checkout view uses it
/// instead of the default "Pay USD 29.99" text.
public struct PayButtonLabelKey: PreferenceKey {
    public static let defaultValue: String? = nil
    public static func reduce(value: inout String?, nextValue: () -> String?) {
        value = nextValue() ?? value
    }
}

// MARK: - Tokens Spent

/// Preference key for the token payment plugin to report the number of tokens
/// needed for the current order. Captured by CheckoutView and forwarded to
/// the confirmation page so it can display "Paid with X tokens".
public struct TokensSpentKey: PreferenceKey {
    public static let defaultValue: Double? = nil
    public static func reduce(value: inout Double?, nextValue: () -> Double?) {
        value = nextValue() ?? value
    }
}
