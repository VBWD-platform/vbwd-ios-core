import Foundation

/// Holds all registered `AppTheme` instances. Extensible via `register()` — new
/// themes are added without modifying existing code (OCP).
public final class ThemeRegistry: @unchecked Sendable {
    private var storage: [String: any AppTheme]
    public var defaultThemeID: String

    public init() {
        self.defaultThemeID = "classic"
        self.storage = [:]
        // Register built-in themes
        register(ClassicTheme())
        register(DarkGreenTheme())
        register(DarkBlueTheme())
    }

    /// All registered themes, sorted by display name.
    public var themes: [any AppTheme] {
        Array(storage.values).sorted { $0.displayName < $1.displayName }
    }

    /// Register a theme. Replaces any existing theme with the same ID.
    public func register(_ theme: any AppTheme) {
        storage[theme.id] = theme
    }

    /// Look up a theme by ID. Returns nil if not found.
    public func theme(for id: String) -> (any AppTheme)? {
        storage[id]
    }
}
