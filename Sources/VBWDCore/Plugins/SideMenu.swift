import SwiftUI

/// Side drawer menu content with header, core items, plugin items, and logout.
/// Sprint 05: uses theme colors. Sprint 06: Store + Billing sections.
public struct SideMenu: View {
    let onClose: () -> Void
    @EnvironmentObject var session: AuthSession
    @EnvironmentObject var host: PluginHost
    @Environment(\.isMenuOpen) var isMenuOpen
    @Environment(\.appTheme) var theme

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    // MARK: - Permission helpers

    private var permissions: [String] {
        session.currentUser?.userPermissions ?? []
    }

    private var canViewTokens: Bool {
        PermissionEvaluator().has("subscription.tokens.view", in: permissions)
    }

    private var canViewInvoices: Bool {
        PermissionEvaluator().has("subscription.invoices.view", in: permissions)
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            MenuHeader(user: session.currentUser)
                .padding()
                .accessibilityIdentifier("menu_header")

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Core items
                    MenuItemButton(
                        icon: "house.fill",
                        title: "Dashboard",
                        action: {
                            host.selectedRoute = nil
                            onClose()
                        }
                    )

                    MenuItemButton(
                        icon: "person.fill",
                        title: "Profile",
                        action: {
                            host.selectedRoute = "/profile"
                            onClose()
                        }
                    )

                    MenuItemButton(
                        icon: "gearshape.fill",
                        title: "Settings",
                        action: {
                            host.selectedRoute = "/settings"
                            onClose()
                        }
                    )

                    // Store section (permission-gated)
                    if canViewTokens {
                        Divider().padding(.vertical, 8)
                        MenuSectionHeader(title: "Store")
                        MenuItemButton(
                            icon: "circle.dotted.circle",
                            title: "Tokens",
                            action: {
                                host.selectedRoute = "/store/tokens"
                                onClose()
                            }
                        )
                        MenuItemButton(
                            icon: "cart.fill",
                            title: "Buy Tokens",
                            action: {
                                host.selectedRoute = "/store/buy-tokens"
                                onClose()
                            }
                        )
                    }

                    // Billing section (permission-gated)
                    if canViewInvoices {
                        Divider().padding(.vertical, 8)
                        MenuSectionHeader(title: "Billing")
                        MenuItemButton(
                            icon: "doc.text.fill",
                            title: "Invoices",
                            action: {
                                host.selectedRoute = "/billing/invoices"
                                onClose()
                            }
                        )
                    }

                    Divider()
                        .padding(.vertical, 8)

                    // Plugin items (injected)
                    PluginMenuItems(onClose: onClose)
                }
            }

            Spacer()

            // Logout
            Divider()
            MenuItemButton(
                icon: "rectangle.portrait.and.arrow.right",
                title: "Logout",
                isDestructive: true,
                action: {
                    host.selectedRoute = nil
                    Task {
                        await session.signOut()
                    }
                    onClose()
                }
            )
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.menuBackground)
        .shadow(radius: 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("side_menu")
    }
}

// MARK: - Section Header

private struct MenuSectionHeader: View {
    let title: String
    @Environment(\.appTheme) var theme

    var body: some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 4)
    }
}
