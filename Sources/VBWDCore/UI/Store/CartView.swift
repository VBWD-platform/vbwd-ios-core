import SwiftUI

/// Container that shows CartView first, then CheckoutView when the user
/// taps "Proceed to Checkout". Manages the cart → checkout transition
/// internally so the parent sheet doesn't need to change its content.
struct CartCheckoutContainer: View {
    let checkoutViewModelFactory: () -> CheckoutViewModel
    @State private var showCheckout = false
    @State private var checkoutVM: CheckoutViewModel?

    var body: some View {
        NavigationView {
            if showCheckout, let vm = checkoutVM {
                CheckoutView(viewModel: vm)
            } else {
                CartView(onCheckout: {
                    checkoutVM = checkoutViewModelFactory()
                    showCheckout = true
                })
            }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
    }
}

/// Cart review screen. Shows all items in the cart with swipe-to-delete
/// on each row, a "Clear Cart" button, and a "Checkout" button to proceed.
/// Presented as a sheet when the user taps the cart icon.
struct CartView: View {
    @EnvironmentObject var cart: Cart
    @Environment(\.appTheme) var theme
    @Environment(\.dismiss) var dismiss

    let onCheckout: () -> Void

    var body: some View {
        Group {
            if cart.isEmpty {
                emptyState
            } else {
                cartContent
            }
        }
        .background(theme.background.ignoresSafeArea())
        .accessibilityIdentifier("cart_view")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    // MARK: - Content

    private var cartContent: some View {
        VStack(spacing: 0) {
            List {
                // Header section
                Section {
                    HStack {
                        Text("Cart").font(.largeTitle).bold()
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Button(role: .destructive) {
                            withAnimation { cart.clear() }
                        } label: {
                            Label("Clear Cart", systemImage: "trash")
                                .font(.subheadline)
                                .foregroundColor(theme.destructive)
                        }
                        .accessibilityIdentifier("clear_cart_button")
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
                }

                // Cart items — swipe left to delete
                Section {
                    ForEach(cart.items) { item in
                        cartRow(item)
                            .listRowBackground(theme.cardBackground)
                    }
                    .onDelete { offsets in
                        let idsToRemove = offsets.map { cart.items[$0].id }
                        withAnimation {
                            for id in idsToRemove {
                                cart.remove(id: id)
                            }
                        }
                    }
                }

                // Total
                Section {
                    HStack {
                        Text("Total")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Text(String(format: "%@ %.2f",
                                     cart.items.first?.currency ?? "USD",
                                     cart.total))
                            .font(.headline)
                            .foregroundColor(theme.accent)
                    }
                    .listRowBackground(theme.cardBackground)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)

            checkoutButton
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
    }

    // MARK: - Row

    private func cartRow(_ item: CartItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .foregroundColor(theme.textPrimary)
                    .fontWeight(.medium)
                Text(item.type.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                if item.quantity > 1 {
                    Text("Qty: \(item.quantity)")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
            }
            Spacer()
            Text(String(format: "%@ %.2f", item.currency,
                         item.price * Double(item.quantity)))
                .fontWeight(.medium)
                .foregroundColor(theme.textPrimary)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("cart_item_\(item.id)")
    }

    // MARK: - Checkout Button

    private var checkoutButton: some View {
        Button {
            onCheckout()
        } label: {
            Text("Proceed to Checkout")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(theme.accent)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .accessibilityIdentifier("proceed_to_checkout_button")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart")
                .font(.system(size: 48))
                .foregroundColor(theme.textSecondary)
            Text("Your cart is empty")
                .font(.headline)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
