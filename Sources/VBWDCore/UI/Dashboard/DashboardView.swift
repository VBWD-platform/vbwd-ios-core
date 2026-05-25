import SwiftUI

/// Generic user dashboard. Port of `Dashboard.vue`: profile card always,
/// permission-gated token/invoice cards, loading state. Thin — logic is in
/// `DashboardViewModel`. Sprint 03: adds widget grid layout and menu button.
/// Sprint 05: uses theme colors.
public struct DashboardView: View {
    @ObservedObject private var viewModel: DashboardViewModel
    @EnvironmentObject var host: PluginHost
    @EnvironmentObject var cart: Cart
    @Environment(\.isMenuOpen) var isMenuOpen
    @Environment(\.appTheme) var theme

    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Dashboard").font(.largeTitle).bold()
                    .foregroundColor(theme.textPrimary)

                if viewModel.isLoading {
                    ProgressView("Loading…").frame(maxWidth: .infinity)
                } else {
                    profileCard
                    if viewModel.showTokenCard { tokenCard }
                    if viewModel.showInvoicesCard { invoicesCard }

                    // Plugin Dashboard* widgets in grid (Sprint 03)
                    if !viewModel.pluginWidgets.isEmpty {
                        DashboardWidgetLayout(widgets: viewModel.pluginWidgets)
                            .padding(.top, 8)
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background.ignoresSafeArea())
        .accessibilityIdentifier("dashboard_view")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                dashboardMenuButton
            }
            #else
            ToolbarItem(placement: .automatic) {
                dashboardMenuButton
            }
            #endif
        }
        .task { await viewModel.load() }
    }

    private var dashboardMenuButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                isMenuOpen.wrappedValue.toggle()
            }
        }) {
            Image(systemName: "line.3.horizontal")
                .font(.title3)
                .overlay(alignment: .topTrailing) {
                    if !cart.isEmpty {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 4, y: -4)
                    }
                }
        }
        .accessibilityIdentifier("menu_button")
    }

    private var profileCard: some View {
        card("Profile") {
            HStack(spacing: 12) {
                Text(viewModel.userInitials)
                    .font(.headline)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(theme.avatarBackground))
                VStack(alignment: .leading) {
                    Text(viewModel.userName).font(.headline)
                        .foregroundColor(theme.textPrimary)
                    Text(viewModel.userEmail).font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
    }

    private var tokenCard: some View {
        card("Token activity") {
            if viewModel.tokenTransactions.isEmpty {
                Text("No activity").foregroundColor(theme.textSecondary)
            } else {
                ForEach(viewModel.tokenTransactions) { tx in
                    HStack {
                        Text(tx.transactionType ?? "—")
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Text(String(format: "%+.0f", tx.amount))
                            .foregroundColor(tx.amount >= 0 ? theme.success : theme.destructive)
                    }
                }
            }
        }
    }

    private var invoicesCard: some View {
        card("Recent invoices") {
            if viewModel.recentInvoices.isEmpty {
                Text("No invoices").foregroundColor(theme.textSecondary)
            } else {
                ForEach(viewModel.recentInvoices) { inv in
                    Button {
                        host.selectedRoute = "/billing/invoice/\(inv.id)"
                    } label: {
                        HStack {
                            Text(inv.invoiceNumber ?? inv.id)
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            Text(inv.amount ?? "—")
                                .foregroundColor(theme.textPrimary)
                            Text(inv.status ?? "")
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("dashboard_invoice_\(inv.id)")
                }
            }
        }
    }

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
