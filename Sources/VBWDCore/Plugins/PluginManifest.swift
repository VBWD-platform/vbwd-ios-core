import Foundation

/// Runtime plugin enable/disable manifest. Exact shape of the live backend
/// `/api/v1/admin/frontend-plugins/<app>` response (verified 2026-05-16) and
/// the web `/plugins.json`: `{ plugins: { name: { enabled, version,
/// installedAt?, source } } }`.
public struct PluginManifest: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let enabled: Bool
        public let version: String
        public let installedAt: String?
        public let source: String

        public init(enabled: Bool, version: String,
                    installedAt: String? = nil, source: String = "local") {
            self.enabled = enabled
            self.version = version
            self.installedAt = installedAt
            self.source = source
        }
    }

    public let plugins: [String: Entry]

    public init(plugins: [String: Entry]) { self.plugins = plugins }

    /// Names whose entry is `enabled` (the gate the registry/host honours).
    public var enabledNames: Set<String> {
        Set(plugins.filter { $0.value.enabled }.keys)
    }

    public func isEnabled(_ name: String) -> Bool {
        plugins[name]?.enabled ?? false
    }

    public static let empty = PluginManifest(plugins: [:])
}

/// Reads the manifest. iOS is **read-only** — the backend is the single writer
/// (CLAUDE.md plugin-management). Port of `manifest.ts` fetch + fallback:
/// `load()` never throws; on any failure it returns the bundled fallback,
/// exactly like the web client.
public protocol PluginManifestLoader: AnyObject, Sendable {
    func load() async -> PluginManifest
}

/// Fetches the manifest from a configurable backend endpoint via the injected
/// `APIClient`; falls back to a bundled manifest on any error (web parity).
public final class RemotePluginManifestLoader: PluginManifestLoader, @unchecked Sendable {
    private let api: APIClient
    private let path: String
    private let fallback: PluginManifest

    public init(api: APIClient, path: String, fallback: PluginManifest = .empty) {
        self.api = api
        self.path = path
        self.fallback = fallback
    }

    public func load() async -> PluginManifest {
        do {
            return try await api.get(path)
        } catch {
            return fallback
        }
    }
}

/// Deterministic loader for tests/previews and the bundled-default path.
public final class InMemoryPluginManifestLoader: PluginManifestLoader, Sendable {
    private let manifest: PluginManifest
    public init(_ manifest: PluginManifest) { self.manifest = manifest }
    public func load() async -> PluginManifest { manifest }
}

/// Loads the manifest from a bundled `plugins.json` file in the app's main
/// bundle. The host app ships this file to define which plugins are enabled by
/// default (offline-safe, no backend dependency). Mirrors the web's
/// `public/plugins.json` convention.
public final class BundledPluginManifestLoader: PluginManifestLoader, @unchecked Sendable {
    private let bundle: Bundle
    private let fileName: String

    public init(bundle: Bundle = .main, fileName: String = "plugins") {
        self.bundle = bundle
        self.fileName = fileName
    }

    public func load() async -> PluginManifest {
        guard let url = bundle.url(forResource: fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data) else {
            return .empty
        }
        return manifest
    }
}
