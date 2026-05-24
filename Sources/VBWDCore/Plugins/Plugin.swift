/// Plugin dependency declaration. Port of the web `dependencies?: string[] |
/// Record<string,string>` — a bare list (any version) or version-constrained.
public enum PluginDependencies: Equatable, Sendable {
    case none
    case list([String])
    case constrained([String: String])

    /// Normalised `(name, constraint)` pairs; bare list ⇒ `*` (any version).
    public var resolved: [(name: String, constraint: VersionConstraint)] {
        switch self {
        case .none:
            return []
        case let .list(names):
            return names.map { ($0, VersionConstraint("*")) }
        case let .constrained(map):
            return map.map { ($0.key, VersionConstraint($0.value)) }
        }
    }
}

/// Plugin manifest/metadata. Port of `IPlugin` fields (types.ts:18-78).
public struct PluginMetadata: Equatable, Sendable {
    public let name: String
    public let version: SemanticVersion
    public let description: String?
    public let author: String?
    public let homepage: String?
    public let keywords: [String]
    public let dependencies: PluginDependencies
    public let translations: [String: [String: String]]

    public init(name: String,
                version: SemanticVersion,
                description: String? = nil,
                author: String? = nil,
                homepage: String? = nil,
                keywords: [String] = [],
                dependencies: PluginDependencies = .none,
                translations: [String: [String: String]] = [:]) {
        self.name = name
        self.version = version
        self.description = description
        self.author = author
        self.homepage = homepage
        self.keywords = keywords
        self.dependencies = dependencies
        self.translations = translations
    }
}

/// Plugin lifecycle state. Port of the web `PluginStatus` enum.
public enum PluginStatus: Equatable, Sendable {
    case registered
    case installed
    case active
    case inactive
    case error(String)
}

/// The contract a third-party plugin implements. Port of `IPlugin`.
/// `install` receives the `PlatformSDK`; the other hooks are optional
/// (default no-op via the protocol extension) exactly like the web hooks.
public protocol Plugin: AnyObject, Sendable {
    var metadata: PluginMetadata { get }
    func install(_ sdk: PlatformSDK) async throws
    func activate() async throws
    func deactivate() async throws
    func uninstall() async throws
}

public extension Plugin {
    func install(_ sdk: PlatformSDK) async throws {}
    func activate() async throws {}
    func deactivate() async throws {}
    func uninstall() async throws {}
}
