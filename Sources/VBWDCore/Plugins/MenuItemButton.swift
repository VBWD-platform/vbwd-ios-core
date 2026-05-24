import SwiftUI

/// Reusable menu item button with icon, title, optional badge, and chevron.
/// Sprint 05: uses theme colors.
public struct MenuItemButton: View {
    let icon: String
    let title: String
    var badge: String? = nil
    var isDestructive: Bool = false
    let action: () -> Void
    @Environment(\.appTheme) var theme

    public init(
        icon: String,
        title: String,
        badge: String? = nil,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.badge = badge
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
