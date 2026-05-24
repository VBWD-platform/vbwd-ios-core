import SwiftUI

/// Full invoice list screen. Sprint 06: Billing > Invoices menu item.
struct InvoicesView: View {
    @ObservedObject var viewModel: InvoicesViewModel
    @Environment(\.appTheme) var theme

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
                    card("") {
                        Text("No invoices")
                            .foregroundColor(theme.textSecondary)
                    }
                } else {
                    ForEach(viewModel.invoices) { inv in
                        invoiceRow(inv)
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - Row

    private func invoiceRow(_ inv: Invoice) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(inv.invoiceNumber ?? inv.id)
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                if let date = inv.invoicedAt {
                    Text(date)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(inv.amount ?? "\u{2014}")
                    .foregroundColor(theme.textPrimary)
                if let status = inv.status {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
        .accessibilityIdentifier("invoice_row_\(inv.id)")
    }

    // MARK: - Helpers

    private func card<Content: View>(_ title: String,
                                     @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !title.isEmpty {
                Text(title).font(.headline)
                    .foregroundColor(theme.textPrimary)
            }
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
    }
}
