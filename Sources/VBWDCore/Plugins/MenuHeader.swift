import SwiftUI

/// Menu header showing user avatar, name, and email.
/// Sprint 05: uses theme colors.
public struct MenuHeader: View {
    let user: AuthUser?
    @Environment(\.appTheme) var theme

    public init(user: AuthUser?) {
        self.user = user
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            Text(user?.name ?? "User")
                .font(.headline)
                .foregroundColor(theme.textPrimary)

            Text(user?.email ?? "")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
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
