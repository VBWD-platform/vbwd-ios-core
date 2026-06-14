import SwiftUI

/// Reusable menu item button with icon, title, optional badge, and chevron.
/// Sprint 05: uses theme colors.
public struct MenuItemButton: View {
    let icon: String
    let title: String
    var badge: String? = nil
    var badgeProvider: BadgeProvider? = nil
    var isDestructive: Bool = false
    let action: () -> Void
    @Environment(\.appTheme) var theme

    public init(
        icon: String,
        title: String,
        badge: String? = nil,
        badgeProvider: BadgeProvider? = nil,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.badge = badge
        self.badgeProvider = badgeProvider
        self.isDestructive = isDestructive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundColor(isDestructive ? theme.destructive : theme.textPrimary)

                Text(title)
                    .foregroundColor(isDestructive ? theme.destructive : theme.textPrimary)

                Spacer()

                if let badge = badge {
                    Text(badge)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(theme.accent)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                if let badgeProvider = badgeProvider {
                    MenuBadgePill(provider: badgeProvider)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("menu_item_\(title)")
    }
}

/// Red unread pill driven by a live `BadgeProvider` (S67.2). Hidden while
/// the count is zero or negative.
public struct MenuBadgePill: View {
    @ObservedObject var provider: BadgeProvider

    public init(provider: BadgeProvider) {
        self.provider = provider
    }

    /// Pure label logic, unit-tested in the runner: nil hides the pill.
    public static func label(for count: Int) -> String? {
        count > 0 ? "\(count)" : nil
    }

    public var body: some View {
        if let label = Self.label(for: provider.count) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.red)
                .foregroundColor(.white)
                .clipShape(Capsule())
                .accessibilityIdentifier("menu_badge_pill")
        }
    }
}
