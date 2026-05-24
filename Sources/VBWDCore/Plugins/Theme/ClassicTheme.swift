import SwiftUI

/// Default iOS look — adapts to system light/dark mode.
public struct ClassicTheme: AppTheme {
    public let id = "classic"
    public let displayName = "Classic"

    public let accent = Color.blue

    #if os(iOS)
    public let background = Color(uiColor: .systemBackground)
    #else
    public let background = Color(nsColor: .windowBackgroundColor)
    #endif

    public let cardBackground = Color.gray.opacity(0.08)
    public let textPrimary = Color.primary
    public let textSecondary = Color.secondary

    public let destructive = Color.red
    public let success = Color.green

    #if os(iOS)
    public let separator = Color(uiColor: .separator)
    public let menuBackground = Color(uiColor: .systemBackground)
    #else
    public let separator = Color(nsColor: .separatorColor)
    public let menuBackground = Color(nsColor: .windowBackgroundColor)
    #endif

    public let avatarBackground = Color.blue.opacity(0.2)

    public let preferredColorScheme: ColorScheme? = nil

    public init() {}
}
