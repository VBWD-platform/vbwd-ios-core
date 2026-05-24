import Foundation

/// Localization lookup over the merged plugin `LocalizationRegistry`.
/// Single resolution path (DRY) used by the shell/views; missing key → key
/// (web i18n fallback). Locale is switchable at runtime.
@MainActor
public final class Localization: ObservableObject {
    @Published public var locale: String
    private let registry: LocalizationRegistry

    public init(registry: LocalizationRegistry, locale: String = "en") {
        self.registry = registry
        self.locale = locale
    }

    public func t(_ key: String) -> String {
        registry.t(key, locale: locale)
    }
}
