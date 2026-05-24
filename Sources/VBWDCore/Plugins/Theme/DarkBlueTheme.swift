import SwiftUI

/// Deep navy with dodger blue accents.
public struct DarkBlueTheme: AppTheme {
    public let id = "dark-blue"
    public let displayName = "Dark Blue"

    public let accent = Color(red: 0.20, green: 0.60, blue: 0.86)       // #3498DB
    public let background = Color(red: 0.05, green: 0.11, blue: 0.16)   // #0D1B2A
    public let cardBackground = Color(red: 0.09, green: 0.15, blue: 0.22)
    public let textPrimary = Color.white
    public let textSecondary = Color(white: 0.7)

    public let destructive = Color(red: 0.91, green: 0.30, blue: 0.24)  // #E74C3C
    public let success = Color(red: 0.18, green: 0.80, blue: 0.44)      // #2ECC71

    public let separator = Color(white: 0.25)
    public let menuBackground = Color(red: 0.04, green: 0.08, blue: 0.13)
    public let avatarBackground = Color(red: 0.20, green: 0.60, blue: 0.86).opacity(0.2)

    public let preferredColorScheme: ColorScheme? = .dark

    public init() {}
}
