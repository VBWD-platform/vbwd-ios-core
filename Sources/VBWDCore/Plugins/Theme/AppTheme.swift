import SwiftUI

/// Defines a color palette for the entire app.
/// To add a new theme: create a struct conforming to AppTheme,
/// then register it with ThemeRegistry.
public protocol AppTheme: Identifiable, Sendable {
    var id: String { get }
    var displayName: String { get }

    // Core palette
    var accent: Color { get }
    var background: Color { get }
    var cardBackground: Color { get }
    var textPrimary: Color { get }
    var textSecondary: Color { get }

    // Semantic
    var destructive: Color { get }
    var success: Color { get }

    // Chrome
    var separator: Color { get }
    var menuBackground: Color { get }
    var avatarBackground: Color { get }

    // Scheme preference
    var preferredColorScheme: ColorScheme? { get }
}
