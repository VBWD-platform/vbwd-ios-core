import SwiftUI

/// Environment key for the current `AppTheme`. Allows any view in the hierarchy
/// to read `@Environment(\.appTheme)` without depending on a concrete type (DIP).
private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: any AppTheme = ClassicTheme()
}

public extension EnvironmentValues {
    var appTheme: any AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
