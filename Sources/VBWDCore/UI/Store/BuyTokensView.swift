import SwiftUI

/// Token bundle storefront. Lists available bundles with name, token amount,
/// and price. Tapping a bundle adds it to the cart and opens the checkout
/// sheet. Sprint 06c: uses the agnostic `Cart` instead of passing items directly.
struct BuyTokensView: View {
    @ObservedObject var viewModel: BuyTokensViewModel
    @Environment(\.appTheme) var theme
    let cart: Cart
    let checkoutViewModelFactory: (CheckoutContext) -> CheckoutViewModel

    @State private var showCheckout = false

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
        .accessibilityIdentifier("buy_tokens_view")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .modifier(MenuToolbar())
        .task { await viewModel.load() }
        .sheet(isPresented: $showCheckout) {
            NavigationView {
                CheckoutView(viewModel: checkoutViewModelFactory(
                    CheckoutContext(source: "token_bundle", isCart: true)))
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Buy Tokens").font(.largeTitle).bold()
                    .foregroundColor(theme.textPrimary)

                if viewModel.bundles.isEmpty {
                    emptyCard
                } else {
                    ForEach(viewModel.bundles) { bundle in
                        Button {
                            selectBundle(bundle)
                        } label: {
                            bundleCard(bundle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("bundle_\(bundle.id)")
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - Actions

    private func selectBundle(_ bundle: TokenBundle) {
        // Clear previous token_bundle items and add the selected one
        for item in cart.items(ofType: "token_bundle") {
            cart.remove(id: item.id)
        }
        cart.add(bundle.toCartItem())
        showCheckout = true
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "circle.dotted.circle")
                .font(.largeTitle)
                .foregroundColor(theme.textSecondary)
            Text("No bundles available")
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
    }

    // MARK: - Bundle Card

    private func bundleCard(_ bundle: TokenBundle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bundle.name)
                        .font(.headline)
                        .foregroundColor(theme.textPrimary)
                    if let desc = bundle.description, !desc.isEmpty {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondary)
                    }
                }
                Spacer()
            }

            HStack {
                Label("\(bundle.tokenAmount) tokens",
                      systemImage: "circle.dotted.circle")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text("\(bundle.currency ?? "USD") \(bundle.price)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.accent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
    }
}
