import SwiftUI

/// Observable theme state. Persists the selected theme ID to UserDefaults.
/// Views observe `currentTheme` to react to theme changes (SRP).
@MainActor
public final class ThemeManager: ObservableObject {
    @Published public private(set) var currentTheme: any AppTheme

    private let registry: ThemeRegistry
    private let defaults: UserDefaults
    private static let persistenceKey = "selectedThemeID"

    public init(registry: ThemeRegistry, defaults: UserDefaults = .standard) {
        self.registry = registry
        self.defaults = defaults

        // Restore persisted theme or fall back to registry default.
        let savedID = defaults.string(forKey: Self.persistenceKey)
        if let savedID,
           let saved = registry.theme(for: savedID) {
            self.currentTheme = saved
        } else {
            self.currentTheme = registry.theme(for: registry.defaultThemeID) ?? ClassicTheme()
        }
    }

    /// Select a theme by ID. Persists to UserDefaults. No-op if ID unknown.
    public func selectTheme(_ id: String) {
        guard let theme = registry.theme(for: id) else { return }
        currentTheme = theme
        defaults.set(id, forKey: Self.persistenceKey)
    }
}
