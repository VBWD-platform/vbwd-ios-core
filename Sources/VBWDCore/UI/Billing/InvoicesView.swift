import SwiftUI

/// Full invoice list screen. Port of the web `Invoices.vue`:
/// date, invoice number, amount with currency, status badge.
/// Sprint 06: Billing > Invoices menu item.
struct InvoicesView: View {
    @ObservedObject var viewModel: InvoicesViewModel
    @EnvironmentObject var host: PluginHost
    @Environment(\.appTheme) var theme

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            if viewModel.isLoading {
                ProgressView("Loading\u{2026}")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .accessibilityIdentifier("invoices_view")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .modifier(MenuToolbar())
        .task { await viewModel.load() }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Invoices").font(.largeTitle).bold()
                    .foregroundColor(theme.textPrimary)

                if viewModel.invoices.isEmpty {
                    emptyCard
                } else {
                    ForEach(viewModel.invoices) { inv in
                        Button {
                            host.selectedRoute = "/billing/invoice/\(inv.id)"
                        } label: {
                            invoiceRow(inv)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("invoice_row_\(inv.id)")
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundColor(theme.textSecondary)
            Text("No invoices")
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
    }

    // MARK: - Row

    private func invoiceRow(_ inv: Invoice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top: invoice number + status badge
            HStack {
                Text(inv.invoiceNumber ?? inv.id)
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                statusBadge(inv.status)
            }

            // Middle: date + payment method
            HStack {
                if let date = inv.invoicedAt {
                    Label(formatDate(date), systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
                if let method = inv.paymentMethod {
                    Label(formatPaymentMethod(method),
                          systemImage: paymentMethodIcon(method))
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
            }

            // Bottom: amount
            HStack {
                Spacer()
                Text(formatAmount(inv))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.accent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
    }

    // MARK: - Status Badge

    private func statusBadge(_ status: String?) -> some View {
        let label = (status ?? "unknown").capitalized
        let (bg, fg) = statusColors(status)

        return Text(label)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(bg))
            .foregroundColor(fg)
    }

    private func statusColors(_ status: String?) -> (Color, Color) {
        switch status?.lowercased() {
        case "paid":
            return (Color.green.opacity(0.15), Color.green)
        case "pending":
            return (Color.orange.opacity(0.15), Color.orange)
        case "overdue", "failed":
            return (Color.red.opacity(0.15), Color.red)
        case "refunded":
            return (Color.gray.opacity(0.15), Color.gray)
        case "cancelled":
            return (Color.gray.opacity(0.1), Color.secondary)
        default:
            return (Color.gray.opacity(0.1), Color.secondary)
        }
    }

    // MARK: - Formatters

    private func formatDate(_ iso: String) -> String {
        // Show just the date portion (first 10 chars of ISO string)
        String(iso.prefix(10))
    }

    private func formatAmount(_ inv: Invoice) -> String {
        let amt = inv.totalAmount ?? inv.amount ?? "0.00"
        let cur = inv.currency ?? "USD"
        return "\(cur) \(amt)"
    }

    private func formatPaymentMethod(_ method: String) -> String {
        switch method.lowercased() {
        case "stripe": return "Stripe"
        case "paypal": return "PayPal"
        case "apple_pay", "apple-pay": return "Apple Pay"
        default: return method.capitalized
        }
    }

    private func paymentMethodIcon(_ method: String) -> String {
        switch method.lowercased() {
        case "stripe": return "creditcard.fill"
        case "paypal": return "dollarsign.circle.fill"
        case "apple_pay", "apple-pay": return "apple.logo"
        default: return "creditcard"
        }
    }
}
