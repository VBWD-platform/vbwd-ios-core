import Foundation

/// App-level configuration loaded from the bundled `vbwd_config.json`.
/// The `.dist` template is committed; the actual file is gitignored so each
/// developer / CI environment can point at its own backend.
///
/// Shape mirrors the JSON:
/// ```json
/// { "api_base_url": "http://localhost:5000/api/v1" }
/// ```
public struct VBWDConfig: Codable, Equatable, Sendable {
    public let apiBaseUrl: String

    enum CodingKeys: String, CodingKey {
        case apiBaseUrl = "api_base_url"
    }

    public init(apiBaseUrl: String) {
        self.apiBaseUrl = apiBaseUrl
    }

    /// Parsed `apiBaseUrl` as a `URL`. Falls back to `SDKContainer.defaultBaseURL`
    /// if the string is malformed.
    public var baseURL: URL {
        URL(string: apiBaseUrl) ?? SDKContainer.defaultBaseURL
    }

    /// Loads config from a bundled `vbwd_config.json` in the given bundle.
    /// Returns `nil` if the file is missing or malformed — caller decides
    /// the fallback (typically `SDKContainer.defaultBaseURL`).
    public static func load(from bundle: Bundle = .main,
                            fileName: String = "vbwd_config") -> VBWDConfig? {
        guard let url = bundle.url(forResource: fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(VBWDConfig.self, from: data) else {
            return nil
        }
        return config
    }
}
