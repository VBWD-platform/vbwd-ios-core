import SwiftUI

/// Basic profile screen showing user info, navigated to from the side menu.
struct ProfileScreen: View {
    let user: AuthUser
    @Environment(\.isMenuOpen) var isMenuOpen

    var body: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Color.blue)
                .frame(width: 80, height: 80)
                .overlay(
                    Text(initials)
                        .font(.title)
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                )
            Text(user.name ?? "User")
                .font(.title2).fontWeight(.semibold)
            Text(user.email)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("profile_view")
        .navigationTitle("Profile")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .modifier(MenuToolbar())
    }

    private var initials: String {
        guard let name = user.name else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return (parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return name.prefix(2).uppercased()
    }
}
