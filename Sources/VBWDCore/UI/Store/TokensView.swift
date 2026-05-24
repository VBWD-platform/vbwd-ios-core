import SwiftUI

/// Dedicated token screen: balance + full transaction list.
/// Sprint 06: Store > Tokens menu item.
struct TokensView: View {
    @ObservedObject var viewModel: TokensViewModel
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
        .accessibilityIdentifier("tokens_view")
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
                Text("Tokens").font(.largeTitle).bold()
                    .foregroundColor(theme.textPrimary)

                balanceCard
                transactionsCard
            }
            .padding(24)
        }
    }

    // MARK: - Cards

    private var balanceCard: some View {
        card("Token Balance") {
            Text(String(format: "%.0f", viewModel.balance))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(theme.accent)
        }
    }

    private var transactionsCard: some View {
        card("Transactions") {
            if viewModel.transactions.isEmpty {
                Text("No transactions")
                    .foregroundColor(theme.textSecondary)
            } else {
                ForEach(viewModel.transactions) { tx in
                    HStack {
                        Text(tx.transactionType ?? "\u{2014}")
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Text(String(format: "%+.0f", tx.amount))
                            .foregroundColor(tx.amount >= 0 ? theme.success : theme.destructive)
                            .fontWeight(.medium)
                    }
                }
            }
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
}
