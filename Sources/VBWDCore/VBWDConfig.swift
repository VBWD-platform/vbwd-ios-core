import Foundation

/// App-level configuration loaded from the bundled `vbwd_config.json`.
/// The `.dist` template is committed; the actual file is gitignored so each
/// developer / CI environment can point at its own backend.
///
/// Shape mirrors the JSON:
/// ```json
/// {
///   "api_base_url": "http://localhost:5000/api/v1",
///   "tarif_plan_root_cat_slug": "ios",
///   "root_ios_category_on_host": "news",
///   "root_ios_post_type_on_host": "post"
/// }
/// ```
public struct VBWDConfig: Codable, Equatable, Sendable {
    public let apiBaseUrl: String
    /// Restricts the visible tariff-plan catalogue to this category (and, when
    /// the backend supports it, its descendants). Forwarded as `?category=<slug>`
    /// to `/tarif-plans` — see `vbwd-backend` `user_plans.py`. `nil` = show all.
    public let tarifPlanRootCatSlug: String?
    /// S91 — category slug on the backend host the iOS CMS "Posts"
    /// browser opens onto. Both this and `rootIosPostTypeOnHost` must
    /// be set for the Posts menu item to appear.
    public let rootIosCategoryOnHost: String?
    /// S91 — registered CMS post-type key (`"post"`, `"page"`,
    /// `"video"`, `"pdf"`, …) the Posts browser filters the archive by.
    public let rootIosPostTypeOnHost: String?
    /// S91 (split-host override) — explicit web origin for the CMS
    /// embed routes. Set this for split-host dev (backend on `:5000`,
    /// fe-user on `:8080`); leave nil for single-host deployments
    /// where stripping `/api/vX` from `apiBaseUrl` gives the right
    /// host. `webOrigin` prefers this key when present.
    public let webBaseUrl: String?
    /// S92 — CMS page slug the shop landing pulls its title / intro
    /// from. Optional; defaults to `"shop"` in the shop plugin when
    /// absent.
    public let rootIosShopHomeSlug: String?
    /// S92 — optional root category slug; when set, the shop home and
    /// category navigator scope to descendants of this category.
    public let rootIosShopRootCatSlug: String?
    /// S92 hybrid — when true, the shop home renders a `WKWebView`
    /// pointed at the CMS embed page identified by
    /// `rootIosShopHomeSlug`, instead of the native featured grid.
    /// Defaults to nil / false → native grid (back-compat).
    public let rootIosShopHomeRendersCmsPage: Bool?

    enum CodingKeys: String, CodingKey {
        case apiBaseUrl = "api_base_url"
        case tarifPlanRootCatSlug = "tarif_plan_root_cat_slug"
        case rootIosCategoryOnHost = "root_ios_category_on_host"
        case rootIosPostTypeOnHost = "root_ios_post_type_on_host"
        case webBaseUrl = "web_base_url"
        case rootIosShopHomeSlug = "root_ios_shop_home_slug"
        case rootIosShopRootCatSlug = "root_ios_shop_root_cat_slug"
        case rootIosShopHomeRendersCmsPage = "root_ios_shop_home_renders_cms_page"
    }

    public init(apiBaseUrl: String,
                tarifPlanRootCatSlug: String? = nil,
                rootIosCategoryOnHost: String? = nil,
                rootIosPostTypeOnHost: String? = nil,
                webBaseUrl: String? = nil,
                rootIosShopHomeSlug: String? = nil,
                rootIosShopRootCatSlug: String? = nil,
                rootIosShopHomeRendersCmsPage: Bool? = nil) {
        self.apiBaseUrl = apiBaseUrl
        self.tarifPlanRootCatSlug = tarifPlanRootCatSlug
        self.rootIosCategoryOnHost = rootIosCategoryOnHost
        self.rootIosPostTypeOnHost = rootIosPostTypeOnHost
        self.webBaseUrl = webBaseUrl
        self.rootIosShopHomeSlug = rootIosShopHomeSlug
        self.rootIosShopRootCatSlug = rootIosShopRootCatSlug
        self.rootIosShopHomeRendersCmsPage = rootIosShopHomeRendersCmsPage
    }

    /// Parsed `apiBaseUrl` as a `URL`. Falls back to `SDKContainer.defaultBaseURL`
    /// if the string is malformed.
    public var baseURL: URL {
        URL(string: apiBaseUrl) ?? SDKContainer.defaultBaseURL
    }

    /// Web origin for the CMS embed routes (S91). Prefers an explicit
    /// `web_base_url` config key (split-host dev), falls back to
    /// stripping `/api/vX` from `apiBaseUrl` (single-host). Returns
    /// `nil` for malformed URLs — the CMS plugin treats that as
    /// "Posts not configured".
    public var webOrigin: URL? {
        // 1. Explicit override wins — needed for split-host dev where
        //    the API is on one port and the web app on another.
        if let webBaseUrl, !webBaseUrl.isEmpty,
           let url = URL(string: webBaseUrl) {
            return url
        }
        // 2. Derive from `apiBaseUrl` by dropping the `/api/v1` suffix.
        guard var components = URLComponents(string: apiBaseUrl) else { return nil }
        let path = components.path
        if let range = path.range(of: "/api/v[0-9]+$",
                                  options: .regularExpression) {
            components.path = String(path[..<range.lowerBound])
        } else if path.hasSuffix("/") {
            components.path = String(path.dropLast())
        }
        components.query = nil
        components.fragment = nil
        return components.url
    }

    /// Archive URL the CMS plugin's WebView opens onto (S91). `nil`
    /// when either config key is absent — the plugin uses that to gate
    /// menu-item visibility.
    public var cmsArchiveURL: URL? {
        guard let webOrigin,
              let type = rootIosPostTypeOnHost, !type.isEmpty,
              let category = rootIosCategoryOnHost, !category.isEmpty else {
            return nil
        }
        return webOrigin.appendingPathComponent("cms/embed/\(type)/\(category)")
    }

    /// URL the shop home loads when `rootIosShopHomeRendersCmsPage` is
    /// true. Returns `nil` when either the flag is off or the inputs
    /// can't compose into a valid URL — the shop plugin treats that as
    /// "fall back to the native grid" (S92 hybrid).
    public var shopHomeCmsPageURL: URL? {
        guard rootIosShopHomeRendersCmsPage == true,
              let webOrigin,
              let slug = rootIosShopHomeSlug, !slug.isEmpty else {
            return nil
        }
        // Mirrors S91's single-page embed shape:
        // `<webOrigin>/cms/embed/<type>/post/<slug>`. Post-type is
        // hard-coded `page` because the shop home is a CMS page (not a
        // category archive).
        return webOrigin
            .appendingPathComponent("cms/embed/page/post/\(slug)")
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
