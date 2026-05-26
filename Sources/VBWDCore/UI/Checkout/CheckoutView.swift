import SwiftUI

/// Checkout screen: order summary, plugin-injected sections (`Checkout*`
/// convention), payment method selection, and Pay button. After submitting,
/// the view transitions through phases: form → processingPayment (Stripe
/// redirect) → confirmation (success page).
///
/// Sprint 06c: Now uses `CartItem` line items from the active `CheckoutSource`
/// instead of `CheckoutItem` protocol array. The source is resolved via
/// `viewModel.loadForContext()`.
public struct CheckoutView: View {
    @ObservedObject var viewModel: CheckoutViewModel
    @Environment(\.appTheme) var theme
    @Environment(\.dismiss) var dismiss
    @State private var payButtonOverride: String?
    @State private var tokensSpent: Double?

    public init(viewModel: CheckoutViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            switch viewModel.phase {
            case .form:
                if viewModel.isLoading {
                    ProgressView("Loading\u{2026}")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    formContent
                }
            case let .processingPayment(url, _):
                PaymentRedirectView(url: url) { callbackURL in
                    viewModel.completePayment(callbackURL: callbackURL)
                }
            case let .confirmation(result):
                CheckoutConfirmationView(result: result, tokensSpent: tokensSpent) {
                    dismiss()
                }
            }
        }
        .background(theme.background.ignoresSafeArea())
        .accessibilityIdentifier("checkout_view")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if viewModel.phase == .form {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await viewModel.loadForContext() }
    }

    // MARK: - Form Content

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Checkout").font(.largeTitle).bold()
                    .foregroundColor(theme.textPrimary)

                orderSummaryCard
                if viewModel.isZeroTotal {
                    zeroTotalNotice
                } else {
                    if viewModel.hasMixedBillingIntervals {
                        mixedIntervalsNotice
                    }
                    paymentMethodsSection
                        .environment(\.checkoutInfo, CheckoutInfo(
                            amount: viewModel.orderTotal,
                            currency: viewModel.currency))
                }
                errorBanner
                payButton
            }
            .padding(24)
        }
        .onPreferenceChange(PayButtonLabelKey.self) { label in
            payButtonOverride = label
        }
        .onPreferenceChange(TokensSpentKey.self) { tokens in
            tokensSpent = tokens
        }
    }

    // MARK: - Order Summary

    private var orderSummaryCard: some View {
        card("Order Summary") {
            ForEach(viewModel.lineItems) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .foregroundColor(theme.textPrimary)
                        if item.quantity > 1 {
                            Text("Qty: \(item.quantity)")
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                    Spacer()
                    Text(String(format: "%@ %.2f", item.currency, item.price * Double(item.quantity)))
                        .fontWeight(.medium)
                        .foregroundColor(theme.textPrimary)
                }
            }

            Divider()

            HStack {
                Text("Total")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Text(String(format: "%@ %.2f", viewModel.currency, viewModel.orderTotal))
                    .font(.headline)
                    .foregroundColor(theme.accent)
            }
        }
    }

    // MARK: - Payment Methods (unified: selector + plugin detail)

    private var paymentMethodsSection: some View {
        card("Payment Method") {
            if viewModel.paymentMethods.isEmpty {
                Text("No payment methods available")
                    .foregroundColor(theme.textSecondary)
            } else {
                ForEach(viewModel.paymentMethods) { method in
                    let isSelected = viewModel.selectedMethodId == method.code

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedMethodId = method.code
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: iconFor(method))
                                .foregroundColor(theme.accent)
                                .frame(width: 24)
                            Text(method.name)
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            Image(systemName: isSelected
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected
                                                 ? theme.accent : theme.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("payment_method_\(method.code)")

                    // Show plugin-provided detail when this method is selected
                    if isSelected,
                       let detail = viewModel.paymentMethodDetail(for: method.code) {
                        detail()
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if method.id != viewModel.paymentMethods.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Mixed Billing Intervals Notice

    private var mixedIntervalsNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(.orange)
            Text("Your cart contains items with different billing intervals. Stripe is not available for this order — please use another payment method.")
                .font(.subheadline)
                .foregroundColor(theme.textPrimary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(Color.orange.opacity(0.08)))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Zero Total Notice

    private var zeroTotalNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundColor(theme.accent)
            Text("Please finish subscription by the button Pay Zero")
                .font(.subheadline)
                .foregroundColor(theme.textPrimary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(theme.accent.opacity(0.08)))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.accent.opacity(0.2), lineWidth: 1)
        )
        .accessibilityIdentifier("zero_total_notice")
    }

    // MARK: - Pay Button

    private var payButton: some View {
        Button {
            Task { await viewModel.submit() }
        } label: {
            Group {
                if viewModel.isSubmitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text(payButtonLabel)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.canSubmit ? theme.accent : theme.accent.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!viewModel.canSubmit)
        .accessibilityIdentifier("checkout_pay_button")
    }

    private var payButtonLabel: String {
        if viewModel.isZeroTotal {
            return "Pay Zero"
        }
        return payButtonOverride
            ?? "Pay \(String(format: "%@ %.2f", viewModel.currency, viewModel.orderTotal))"
    }

    // MARK: - Error

    @ViewBuilder
    private var errorBanner: some View {
        if let error = viewModel.errorMessage {
            Text(error)
                .foregroundColor(theme.destructive)
                .font(.callout)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(theme.destructive.opacity(0.1)))
        }
    }

    // MARK: - Helpers

    private func card<Content: View>(_ title: String,
                                     @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
                .foregroundColor(theme.textPrimary)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
    }

    private func iconFor(_ method: PaymentMethod) -> String {
        if let icon = method.icon, !icon.isEmpty { return icon }
        switch method.code.lowercased() {
        case let c where c.contains("apple"): return "apple.logo"
        case let c where c.contains("stripe"): return "creditcard.fill"
        case let c where c.contains("paypal"): return "dollarsign.circle.fill"
        case let c where c.contains("invoice"): return "doc.text.fill"
        case let c where c.contains("token"): return "dollarsign.circle"
        default: return "creditcard"
        }
    }
}
