import SwiftUI

/// Invoice detail page. Shows the full invoice with line items and a
/// PDF download button. Port of the web `InvoiceDetail.vue`.
struct InvoiceDetailView: View {
    @ObservedObject var viewModel: InvoiceDetailViewModel
    @EnvironmentObject var host: PluginHost
    @Environment(\.appTheme) var theme

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            if viewModel.isLoading {
                ProgressView("Loading\u{2026}")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let invoice = viewModel.invoice {
                invoiceContent(invoice)
            } else if let error = viewModel.errorMessage {
                errorView(error)
            }
        }
        .accessibilityIdentifier("invoice_detail_view")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .modifier(BackButtonToolbar(backRoute: "/billing/invoices"))
        .task { await viewModel.load() }
        #if os(iOS)
        .sheet(isPresented: pdfPresented) {
            if let url = viewModel.pdfURL {
                ShareSheet(items: [url])
            }
        }
        #endif
    }

    private var pdfPresented: Binding<Bool> {
        Binding(
            get: { viewModel.pdfURL != nil },
            set: { if !$0 { viewModel.clearPDF() } }
        )
    }

    // MARK: - Content

    private func invoiceContent(_ inv: Invoice) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text(inv.invoiceNumber ?? "Invoice")
                    .font(.largeTitle).bold()
                    .foregroundColor(theme.textPrimary)

                // Status banner
                statusBanner(inv)

                // Token payment card (when paid with tokens)
                tokenPaymentCard(inv)

                // Details card
                detailsCard(inv)

                // Line items
                if let items = inv.lineItems, !items.isEmpty {
                    lineItemsCard(items, inv)
                }

                // PDF download button
                downloadButton
            }
            .padding(24)
        }
    }

    // MARK: - Status Banner

    private func statusBanner(_ inv: Invoice) -> some View {
        let status = (inv.status ?? "unknown").lowercased()
        let (icon, title, color) = statusInfo(status)

        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                if let date = inv.paidAt {
                    Text("Paid on \(formatDate(date))")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                } else if let due = inv.expiresAt {
                    Text("Due by \(formatDate(due))")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
            }
            Spacer()
            statusBadge(inv.status)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.08)))
    }

    // MARK: - Token Payment Card

    @ViewBuilder
    private func tokenPaymentCard(_ inv: Invoice) -> some View {
        if inv.paymentMethod?.lowercased() == "token_balance" {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "circle.circle.fill")
                        .foregroundColor(theme.success)
                    Text("Paid with Tokens")
                        .font(.headline).fontWeight(.semibold)
                        .foregroundColor(theme.textPrimary)
                }

                Divider()

                HStack {
                    Text("Amount paid")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Text(formatAmount(inv.totalAmount ?? inv.amount ?? "0.00", inv.currency))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.success.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Details Card

    private func detailsCard(_ inv: Invoice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invoice Details")
                .font(.headline)
                .foregroundColor(theme.textPrimary)

            if let number = inv.invoiceNumber {
                detailRow("Invoice Number", number)
            }

            if let date = inv.invoicedAt {
                detailRow("Date", formatDate(date))
            }

            if let due = inv.expiresAt {
                detailRow("Due Date", formatDate(due))
            }

            if let method = inv.paymentMethod {
                detailRow("Payment Method", formatPaymentMethod(method))
            }

            if let ref = inv.paymentRef, !ref.isEmpty {
                detailRow("Reference", ref)
            }

            Divider()

            if let subtotal = inv.subtotal {
                detailRow("Subtotal", formatAmount(subtotal, inv.currency))
            }

            if let tax = inv.taxAmount, tax != "0.00" && tax != "0" {
                detailRow("Tax", formatAmount(tax, inv.currency))
            }

            HStack {
                Text("Total")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Text(formatAmount(inv.totalAmount ?? inv.amount ?? "0.00", inv.currency))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(theme.accent)
            }
            .padding(.vertical, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
    }

    // MARK: - Line Items

    private func lineItemsCard(_ items: [InvoiceLineItem], _ inv: Invoice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items")
                .font(.headline)
                .foregroundColor(theme.textPrimary)

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.description ?? "Item")
                            .foregroundColor(theme.textPrimary)
                        if let qty = item.quantity, qty > 1,
                           let unitPrice = item.unitPrice {
                            Text("\(qty) × \(formatAmount(unitPrice, inv.currency))")
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                    Spacer()
                    Text(formatAmount(item.amount ?? "0.00", inv.currency))
                        .fontWeight(.medium)
                        .foregroundColor(theme.textPrimary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
    }

    // MARK: - Download Button

    private var downloadButton: some View {
        Button {
            Task { await viewModel.downloadPDF() }
        } label: {
            HStack {
                if viewModel.isDownloading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.down.doc.fill")
                }
                Text(viewModel.isDownloading ? "Downloading\u{2026}" : "Download PDF")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(theme.accent)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(viewModel.isDownloading)
        .accessibilityIdentifier("download_pdf_button")
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(theme.textSecondary)
            Button("Retry") { Task { await viewModel.load() } }
                .foregroundColor(theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func statusBadge(_ status: String?) -> some View {
        let label = (status ?? "unknown").capitalized
        let (_, color) = statusColors(status)

        return Text(label)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundColor(color)
    }

    private func statusInfo(_ status: String) -> (String, String, Color) {
        switch status {
        case "paid":
            return ("checkmark.circle.fill", "Paid", .green)
        case "pending":
            return ("clock.fill", "Payment Pending", .orange)
        case "authorized":
            return ("checkmark.shield.fill", "Authorized", .blue)
        case "failed":
            return ("xmark.circle.fill", "Payment Failed", .red)
        case "cancelled":
            return ("xmark.circle.fill", "Cancelled", .gray)
        case "refunded":
            return ("arrow.uturn.backward.circle.fill", "Refunded", .gray)
        default:
            return ("doc.text.fill", "Unknown", .secondary)
        }
    }

    private func statusColors(_ status: String?) -> (Color, Color) {
        switch status?.lowercased() {
        case "paid": return (Color.green.opacity(0.15), Color.green)
        case "pending": return (Color.orange.opacity(0.15), Color.orange)
        case "overdue", "failed": return (Color.red.opacity(0.15), Color.red)
        case "refunded": return (Color.gray.opacity(0.15), Color.gray)
        case "cancelled": return (Color.gray.opacity(0.1), Color.secondary)
        default: return (Color.gray.opacity(0.1), Color.secondary)
        }
    }

    private func formatDate(_ iso: String) -> String {
        String(iso.prefix(10))
    }

    private func formatAmount(_ amount: String, _ currency: String?) -> String {
        let cur = currency ?? "USD"
        return "\(cur) \(amount)"
    }

    private func formatPaymentMethod(_ method: String) -> String {
        switch method.lowercased() {
        case "stripe": return "Stripe"
        case "paypal": return "PayPal"
        case "invoice": return "Bank Transfer"
        case "apple_pay", "apple-pay": return "Apple Pay"
        case "token_balance": return "Token Balance"
        default: return method.capitalized
        }
    }
}

// MARK: - Share Sheet (iOS)

#if os(iOS)
/// UIKit share sheet wrapper for sharing the downloaded PDF file.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
#endif
