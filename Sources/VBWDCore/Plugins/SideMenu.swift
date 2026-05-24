import SwiftUI

/// Side drawer menu content with header, core items, plugin items, and logout.
/// Sprint 05: uses theme colors.
public struct SideMenu: View {
    let onClose: () -> Void
    @EnvironmentObject var session: AuthSession
    @EnvironmentObject var host: PluginHost
    @Environment(\.isMenuOpen) var isMenuOpen
    @Environment(\.appTheme) var theme

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

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
