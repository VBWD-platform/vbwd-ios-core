import SwiftUI

/// Checkout screen: order summary, plugin-injected sections (`Checkout*`
/// convention), payment method selection, and Pay button. Payment providers
/// (Apple Pay, Stripe, etc.) are implemented as iOS plugins — core only
/// renders the selection and submits the checkout request.
struct CheckoutView: View {
    @ObservedObject var viewModel: CheckoutViewModel
    @Environment(\.appTheme) var theme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading\u{2026}")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .background(theme.background.ignoresSafeArea())
        .accessibilityIdentifier("checkout_view")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .task { await viewModel.loadPaymentMethods() }
        .onChange(of: viewModel.checkoutResult != nil) { completed in
            if completed { dismiss() }
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Checkout").font(.largeTitle).bold()
                    .foregroundColor(theme.textPrimary)

                orderSummaryCard
                pluginSections
                paymentMethodCard
                errorBanner
                payButton
            }
            .padding(24)
        }
    }

    // MARK: - Order Summary

    private var orderSummaryCard: some View {
        card("Order Summary") {
            ForEach(Array(viewModel.items.enumerated()), id: \.offset) { _, item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.checkoutItemName)
                            .foregroundColor(theme.textPrimary)
                        if item.checkoutItemQuantity > 1 {
                            Text("Qty: \(item.checkoutItemQuantity)")
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                    Spacer()
                    Text("\(item.checkoutItemCurrency) \(item.checkoutItemPrice)")
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

    // MARK: - Plugin Sections

    @ViewBuilder
    private var pluginSections: some View {
        let comps = viewModel.checkoutComponents
        if !comps.isEmpty {
            ForEach(comps, id: \.name) { entry in
                entry.factory()
            }
        }
    }

    // MARK: - Payment Methods

    private var paymentMethodCard: some View {
        card("Payment Method") {
            if viewModel.paymentMethods.isEmpty {
                Text("No payment methods available")
                    .foregroundColor(theme.textSecondary)
            } else {
                ForEach(viewModel.paymentMethods) { method in
                    Button {
                        viewModel.selectedMethodId = method.code
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: iconFor(method))
                                .foregroundColor(theme.accent)
                                .frame(width: 24)
                            Text(method.name)
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            if viewModel.selectedMethodId == method.code {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(theme.accent)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("payment_method_\(method.code)")
                }
            }
        }
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
                    Text("Pay \(String(format: "%@ %.2f", viewModel.currency, viewModel.orderTotal))")
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
        default: return "creditcard"
        }
    }
}
