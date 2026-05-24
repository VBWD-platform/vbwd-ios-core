import SwiftUI
import VBWDCore

/// Fake theme for testing registration and lookup.
struct FakeTheme: AppTheme {
    let id: String
    let displayName: String

    let accent = Color.orange
    let background = Color.white
    let cardBackground = Color.gray
    let textPrimary = Color.black
    let textSecondary = Color.gray

    let destructive = Color.red
    let success = Color.green

    let separator = Color.gray
    let menuBackground = Color.white
    let avatarBackground = Color.orange.opacity(0.2)

    let preferredColorScheme: ColorScheme? = nil

    init(id: String = "custom", displayName: String = "Custom") {
        self.id = id
        self.displayName = displayName
    }
}
