import Foundation
import VBWDCore
import VBWDCoreTestKit

func registerCompositionSuites(_ runner: TestRunner) {

    // MARK: S10 — RootRouter (auth-guard decision, web router parity)
    runner.suite("S10 RootRouter") { s in
        await s.test("signedOut_routesToLogin") {
            s.expectEqual(RootRouter.route(for: .signedOut), .login)
        }
        await s.test("error_routesToLogin") {
            s.expectEqual(RootRouter.route(for: .error("x")), .login)
        }
        await s.test("authenticating_routesToLoading") {
            s.expectEqual(RootRouter.route(for: .authenticating), .loading)
        }
        await s.test("authenticated_routesToDashboard_withUser") {
            let u = Fixtures.user(name: "Zed")
            s.expectEqual(RootRouter.route(for: .authenticated(u)), .dashboard(u))
        }
    }

    // MARK: S10 — SDKContainer (composition root / DI)
    runner.suite("S10 SDKContainer") { s in
        await s.test("container_resolvesAuthSession_signedOutByDefault") { @MainActor in
            let c = SDKContainer(tokenStore: InMemoryTokenStore())
            s.expectEqual(c.session.state, .signedOut)
        }
        await s.test("container_baseURL_defaultsToLocalBackend") { @MainActor in
            // No vbwd_config.json in test runner bundle → falls back to defaultBaseURL
            let c = SDKContainer(tokenStore: InMemoryTokenStore())
            s.expectEqual(c.config.baseURL.absoluteString,
                          "http://localhost:5000/api/v1")
        }
        await s.test("container_baseURL_overridable") { @MainActor in
            let url = URL(string: "https://api.prod.example/api/v1")!
            let c = SDKContainer(baseURL: url, tokenStore: InMemoryTokenStore())
            s.expectEqual(c.config.baseURL, url)
        }
        await s.test("container_restoresSession_fromInjectedStore") { @MainActor in
            let store = InMemoryTokenStore()
            try store.saveToken("T")
            try store.saveUser(Data(#"{"id":"1","email":"e@x.io"}"#.utf8))
            let c = SDKContainer(tokenStore: store)
            c.session.start()
            s.expect(c.session.isAuthenticated)
            s.expectEqual(c.session.currentUser?.email, "e@x.io")
        }
        await s.test("container_makesLoginAndDashboardViewModels") { @MainActor in
            let c = SDKContainer(tokenStore: InMemoryTokenStore())
            _ = c.makeLoginViewModel()
            _ = c.makeDashboardViewModel(user: Fixtures.user())
            s.expect(true) // construction did not trap
        }
    }

    // MARK: S10 — VBWDConfig
    runner.suite("S10 VBWDConfig") { s in
        await s.test("decode_validJSON") {
            let json = #"{"api_base_url":"http://localhost:5000/api/v1"}"#
            let config = try JSONDecoder().decode(VBWDConfig.self,
                                                  from: Data(json.utf8))
            s.expectEqual(config.apiBaseUrl, "http://localhost:5000/api/v1")
            s.expectEqual(config.baseURL.absoluteString, "http://localhost:5000/api/v1")
        }

        await s.test("baseURL_malformedString_fallsBackToDefault") {
            let config = VBWDConfig(apiBaseUrl: "")
            s.expectEqual(config.baseURL, SDKContainer.defaultBaseURL)
        }

        await s.test("load_missingFile_returnsNil") {
            // Test runner bundle has no vbwd_config.json
            let result = VBWDConfig.load()
            s.expectNil(result)
        }

        // MARK: S91 — CMS posts browser keys + derived URLs
        await s.test("S91_decode_populatesIosCmsKeys") {
            let json = """
            {
                "api_base_url": "https://vbwd.cc/api/v1",
                "root_ios_category_on_host": "news",
                "root_ios_post_type_on_host": "post"
            }
            """
            let config = try JSONDecoder().decode(VBWDConfig.self,
                                                  from: Data(json.utf8))
            s.expectEqual(config.rootIosCategoryOnHost, "news")
            s.expectEqual(config.rootIosPostTypeOnHost, "post")
        }

        await s.test("S91_decode_keysOptional_backCompat") {
            // A pre-S91 config without the two iOS keys still loads.
            let json = #"{"api_base_url":"http://localhost:5000/api/v1"}"#
            let config = try JSONDecoder().decode(VBWDConfig.self,
                                                  from: Data(json.utf8))
            s.expectNil(config.rootIosCategoryOnHost)
            s.expectNil(config.rootIosPostTypeOnHost)
        }

        await s.test("S91_webOrigin_stripsApiV1") {
            let config = VBWDConfig(apiBaseUrl: "https://vbwd.cc/api/v1")
            s.expectEqual(config.webOrigin?.absoluteString, "https://vbwd.cc")
        }

        await s.test("S91_webOrigin_explicitOverrideWins") {
            // Split-host dev: backend on :5000, fe-user on :8080. The
            // explicit `web_base_url` must win — derive-from-api would
            // land on the wrong port.
            let config = VBWDConfig(
                apiBaseUrl: "http://localhost:5000/api/v1",
                webBaseUrl: "http://localhost:8080")
            s.expectEqual(config.webOrigin?.absoluteString, "http://localhost:8080")
        }

        await s.test("S91_webOrigin_stripsApiVersionGeneric") {
            // /api/v2 also stripped — keeps the helper future-proof.
            let config = VBWDConfig(apiBaseUrl: "https://example.test/api/v2")
            s.expectEqual(config.webOrigin?.absoluteString, "https://example.test")
        }

        await s.test("S91_cmsArchiveURL_requiresBothKeys") {
            // Neither key set → nil.
            s.expectNil(VBWDConfig(apiBaseUrl: "https://vbwd.cc/api/v1")
                .cmsArchiveURL)
            // Only one set → still nil (gate).
            s.expectNil(VBWDConfig(apiBaseUrl: "https://vbwd.cc/api/v1",
                                   rootIosCategoryOnHost: "news").cmsArchiveURL)
            s.expectNil(VBWDConfig(apiBaseUrl: "https://vbwd.cc/api/v1",
                                   rootIosPostTypeOnHost: "post").cmsArchiveURL)
        }

        await s.test("S91_cmsArchiveURL_buildsEmbedPath") {
            let config = VBWDConfig(
                apiBaseUrl: "https://vbwd.cc/api/v1",
                rootIosCategoryOnHost: "news",
                rootIosPostTypeOnHost: "video")
            s.expectEqual(config.cmsArchiveURL?.absoluteString,
                          "https://vbwd.cc/cms/embed/video/news")
        }

        // MARK: S92 — shop hybrid home

        await s.test("S92_shopHomeCmsPageURL_nilWhenFlagOff") {
            let config = VBWDConfig(
                apiBaseUrl: "https://vbwd.cc/api/v1",
                rootIosShopHomeSlug: "shop")
            s.expectNil(config.shopHomeCmsPageURL,
                        "Flag must be true to activate the WebView render.")
        }

        await s.test("S92_shopHomeCmsPageURL_nilWhenSlugMissing") {
            let config = VBWDConfig(
                apiBaseUrl: "https://vbwd.cc/api/v1",
                rootIosShopHomeRendersCmsPage: true)
            s.expectNil(config.shopHomeCmsPageURL,
                        "Flag + slug are both required.")
        }

        await s.test("S92_shopHomeCmsPageURL_buildsEmbedPagePath") {
            let config = VBWDConfig(
                apiBaseUrl: "https://vbwd.cc/api/v1",
                rootIosShopHomeSlug: "storefront",
                rootIosShopHomeRendersCmsPage: true)
            s.expectEqual(config.shopHomeCmsPageURL?.absoluteString,
                          "https://vbwd.cc/cms/embed/page/post/storefront")
        }

        await s.test("S92_shopHomeCmsPageURL_respectsWebBaseUrlOverride") {
            // Split-host dev — explicit web base wins.
            let config = VBWDConfig(
                apiBaseUrl: "http://localhost:5000/api/v1",
                webBaseUrl: "http://localhost:8080",
                rootIosShopHomeSlug: "storefront",
                rootIosShopHomeRendersCmsPage: true)
            s.expectEqual(config.shopHomeCmsPageURL?.absoluteString,
                          "http://localhost:8080/cms/embed/page/post/storefront")
        }
    }
}
