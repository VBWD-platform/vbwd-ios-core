/// Merged plugin translations. Port of i18n `addTranslations`/`getTranslations`:
/// repeated calls for the same locale deep-merge (last write wins per key);
/// `t` returns the key itself when missing (web i18n fallback).
public final class LocalizationRegistry {
    private var byLocale: [String: [String: String]] = [:]

    public init() {}

    public func add(_ locale: String, _ messages: [String: String]) {
        byLocale[locale, default: [:]].merge(messages) { _, new in new }
    }

    public func all() -> [String: [String: String]] { byLocale }

    public func t(_ key: String, locale: String) -> String {
        byLocale[locale]?[key] ?? key
    }
}
