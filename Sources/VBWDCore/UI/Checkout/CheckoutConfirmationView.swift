import SwiftUI

/// Post-checkout success / confirmation page. Shows a status banner,
/// invoice details (number, amount, status, payment method), and line items.
/// Mirrors the web `CheckoutConfirmationView.vue`.
struct CheckoutConfirmationView: View {
    let result: CheckoutResult
    let onDone: () -> Void

    @Environment(\.appTheme) var theme

    private var invoice: CheckoutInvoice? { result.invoice }

    private var paymentStatus: String {
        (invoice?.status ?? "pending").lowercased()
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statusBanner
                if invoice != nil {
                    invoiceDetailsCard
                    lineItemsCard
                }
                doneButton
            }
            .padding(24)
        }
        .accessibilityIdentifier("checkout_confirmation")
    }

    // MARK: - Status Banner

    private var statusBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.system(size: 40))
                .foregroundColor(statusColor)

            Text(statusTitle)
                .font(.title2).bold()
                .foregroundColor(theme.textPrimary)

            Text(statusMessage)
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 12).fill(statusBackground))
        .accessibilityIdentifier("confirmation_banner")
    }

    // MARK: - Invoice Details

    private var invoiceDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Details")
                .font(.headline)
                .foregroundColor(theme.textPrimary)

            if let number = invoice?.invoiceNumber {
                detailRow("Invoice", number)
            }

            detailRow("Status", paymentStatus.capitalized) {
                statusBadge
            }

            if let amount = displayAmount {
                detailRow("Amount", amount)
            }

            if let method = invoice?.paymentMethod, !method.isEmpty {
                detailRow("Payment Method", method.capitalized)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
    }

    // MARK: - Line Items

    @ViewBuilder
    private var lineItemsCard: some View {
        if let items = invoice?.lineItems, !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Items")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)

                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.description ?? "Item")
                                .foregroundColor(theme.textPrimary)
                            if let qty = item.quantity, qty > 1 {
                                Text("Qty: \(qty)")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        Spacer()
                        Text(formatPrice(item.amount))
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
                    Text(displayAmount ?? "")
                        .font(.headline)
                        .foregroundColor(theme.accent)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
        }
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button {
            onDone()
        } label: {
            Text("Done")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(theme.accent)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .accessibilityIdentifier("confirmation_done_button")
    }

    // MARK: - Helpers

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(theme.textSecondary)
            Spacer()
            Text(value)
                .foregroundColor(theme.textPrimary)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }

    private func detailRow<Trailing: View>(_ label: String, _ value: String,
                                            @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(label)
                .foregroundColor(theme.textSecondary)
            Spacer()
            trailing()
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        Text(paymentStatus.capitalized)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(statusBackground))
            .foregroundColor(statusColor)
    }

    private var displayAmount: String? {
        let amount = invoice?.totalAmount ?? invoice?.amount
        guard let amount else { return nil }
        let currency = invoice?.currency ?? "USD"
        return "\(currency) \(amount)"
    }

    private func formatPrice(_ amount: String?) -> String {
        guard let amount else { return "" }
        let currency = invoice?.currency ?? "USD"
        return "\(currency) \(amount)"
    }

    private var statusTitle: String {
        switch paymentStatus {
        case "paid": return "Payment Successful"
        case "pending": return "Payment Processing"
        case "authorized": return "Payment Authorized"
        case "failed": return "Payment Failed"
        case "cancelled": return "Payment Cancelled"
        default: return "Order Received"
        }
    }

    private var statusMessage: String {
        switch paymentStatus {
        case "paid": return "Your payment has been processed successfully. Thank you for your order!"
        case "pending": return "Your payment is being processed. You will receive a confirmation email."
        case "authorized": return "Your payment has been authorized and will be charged upon completion."
        case "failed": return "Your payment could not be processed. Please try again."
        case "cancelled": return "Your payment was cancelled."
        default: return "Your order has been received."
        }
    }

    private var statusIcon: String {
        switch paymentStatus {
        case "paid": return "checkmark.circle.fill"
        case "pending": return "clock.fill"
        case "authorized": return "checkmark.shield.fill"
        case "failed": return "xmark.circle.fill"
        case "cancelled": return "xmark.circle.fill"
        default: return "doc.text.fill"
        }
    }

    private var statusColor: Color {
        switch paymentStatus {
        case "paid", "authorized": return .green
        case "pending": return .orange
        case "failed", "cancelled": return .red
        default: return theme.accent
        }
    }

    private var statusBackground: Color {
        statusColor.opacity(0.12)
    }
}
