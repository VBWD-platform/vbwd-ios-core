import SwiftUI

/// Menu header showing user avatar, name, email, and cart shortcut.
/// Sprint 05: uses theme colors.
public struct MenuHeader: View {
    let user: AuthUser?
    let onCartTap: (() -> Void)?
    @Environment(\.appTheme) var theme
    @EnvironmentObject var cart: Cart

    public init(user: AuthUser?, onCartTap: (() -> Void)? = nil) {
        self.user = user
        self.onCartTap = onCartTap
    }

    public var body: some View {
        HStack(alignment: .top) {
            // Avatar circle
            Circle()
                .fill(theme.accent)
                .frame(width: 60, height: 60)
                .overlay(
                    Text(userInitials)
                        .font(.title2)
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(user?.name ?? "User")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)

                Text(user?.email ?? "")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.top, 8)

            Spacer()

            // Cart button
            if !cart.isEmpty {
                Button {
                    onCartTap?()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(theme.cardBackground)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "cart.fill")
                                    .font(.title2)
                                    .foregroundColor(theme.textPrimary)
                            )

                        Text("\(cart.itemCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }
                .accessibilityIdentifier("menu_cart_button")
            }
        }
    }

    private var userInitials: String {
        guard let name = user?.name else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return (parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return name.prefix(2).uppercased()
    }
}
