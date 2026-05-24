import SwiftUI

/// Dark background with emerald green accents.
public struct DarkGreenTheme: AppTheme {
    public let id = "dark-green"
    public let displayName = "Dark Green"

    public let accent = Color(red: 0.18, green: 0.80, blue: 0.44)       // #2ECC71
    public let background = Color(red: 0.10, green: 0.10, blue: 0.18)   // #1A1A2E
    public let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.22)
    public let textPrimary = Color.white
    public let textSecondary = Color(white: 0.7)

    public let destructive = Color(red: 0.91, green: 0.30, blue: 0.24)  // #E74C3C
    public let success = Color(red: 0.18, green: 0.80, blue: 0.44)      // #2ECC71

    public let separator = Color(white: 0.25)
    public let menuBackground = Color(red: 0.08, green: 0.08, blue: 0.15)
    public let avatarBackground = Color(red: 0.18, green: 0.80, blue: 0.44).opacity(0.2)

    public let preferredColorScheme: ColorScheme? = .dark

    public init() {}
}
