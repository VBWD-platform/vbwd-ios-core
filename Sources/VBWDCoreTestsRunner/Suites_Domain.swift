import Foundation
import VBWDCore
import VBWDCoreTestKit

func registerDomainSuites(_ runner: TestRunner) {

    // MARK: S5 — Credentials / LoginResponse / AuthUser
    runner.suite("S5 Models") { s in
        await s.test("credentials_encodes_email_and_password_keys") {
            let data = try JSONEncoder().encode(Credentials(email: "a@b.c", password: "p"))
            let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            s.expectEqual(obj["email"] as? String, "a@b.c")
            s.expectEqual(obj["password"] as? String, "p")
        }

        await s.test("loginResponse_decodes_login_success_fixture") {
            let r = try JSONDecoder().decode(
                LoginResponse.self, from: loadFixture("login_success.json"))
            s.expectEqual(r.success, true)
            s.expectEqual(r.token, "TEST_TOKEN")
            s.expectEqual(r.user?.email, "test@example.com")
            s.expectEqual(r.userId, "31c0e59c-aae5-4eba-9328-98b99370bf32")
        }

        await s.test("loginResponse_decodes_login_error_fixture_withErrorMessage") {
            let r = try JSONDecoder().decode(
                LoginResponse.self, from: loadFixture("login_error.json"))
            s.expectEqual(r.success, false)
            s.expectEqual(r.error, "Invalid credentials")
            s.expectNil(r.token)
            s.expectNil(r.user)
        }

        await s.test("loginResponse_snakeCase_refresh_token_mapsToRefreshToken") {
            let json = Data("""
            {"success":true,"token":"t","refresh_token":"R","user":null}
            """.utf8)
            let r = try JSONDecoder().decode(LoginResponse.self, from: json)
            s.expectEqual(r.refreshToken, "R")
        }

        await s.test("loginResponse_missing_refresh_token_decodesAsNil") {
            let json = Data(#"{"success":true,"token":"t","user":null}"#.utf8)
            let r = try JSONDecoder().decode(LoginResponse.self, from: json)
            s.expectNil(r.refreshToken)
        }

        await s.test("authUser_decodes_fixture_with_permissions_and_accessLevels") {
            let u = try JSONDecoder().decode(
                AuthUser.self, from: loadFixture("auth_user.json"))
            s.expectEqual(u.email, "test@example.com")
            s.expectEqual(u.name, "John Bach")
            s.expect(u.userPermissions?.contains("subscription.tokens.view") == true)
            s.expectEqual(u.userAccessLevels?.first?.slug, "logged-in")
            s.expectEqual(u.isAdmin, false)
        }

        await s.test("authUser_missing_optional_fields_defaultToNil") {
            let u = try JSONDecoder().decode(
                AuthUser.self, from: Data(#"{"id":"1","email":"e@x.io"}"#.utf8))
            s.expectNil(u.name)
            s.expectNil(u.userPermissions)
            s.expectNil(u.role)
        }
    }

    // MARK: S4 — PermissionEvaluator
    runner.suite("S4 PermissionEvaluator") { s in
        let e = PermissionEvaluator()
        await s.test("star_grantsAnyPermission") {
            s.expect(e.has("anything.at.all", in: ["*"]))
        }
        await s.test("exactMatch_grants") {
            s.expect(e.has("user.profile.view", in: ["user.profile.view"]))
        }
        await s.test("prefixWildcard_shopStar_matches_shop_products_view") {
            s.expect(e.has("shop.products.view", in: ["shop.*"]))
        }
        await s.test("prefixWildcard_boundary_shopx_notMatchedByShopStar") {
            s.expect(!e.has("shopx", in: ["shop.*"]))
        }
        await s.test("emptyPermissions_deniesEverything") {
            s.expect(!e.has("anything", in: []))
        }
        await s.test("hasAny_returnsTrue_onAMatch") {
            s.expect(e.hasAny(["a", "subscription.tokens.view"],
                              in: ["subscription.*"]))
        }
        await s.test("hasAny_allMissing_returnsFalse") {
            s.expect(!e.hasAny(["a", "b"], in: ["c", "d"]))
        }
    }

    // MARK: S6 — DefaultAuthService
    runner.suite("S6 DefaultAuthService") { s in

        func makeService(_ router: @escaping SpyAPIClient.Router)
            -> (DefaultAuthService, SpyAPIClient, InMemoryTokenStore) {
            let spy = SpyAPIClient(router: router)
            let store = InMemoryTokenStore()
            return (DefaultAuthService(client: spy, store: store), spy, store)
        }

        let successRouter: SpyAPIClient.Router = { path, method, _ in
            switch (method, path) {
            case (.post, "/auth/login"):
                return (200, (try? loadFixture("login_success.json")) ?? Data())
            case (.post, "/auth/logout"):
                return (200, Data(#"{"message":"Logged out successfully"}"#.utf8))
            case (.get, "/user/profile"):
                return (200, (try? loadFixture("auth_user.json")) ?? Data())
            default:
                return (404, Data(#"{"error":"no route"}"#.utf8))
            }
        }

        await s.test("login_success_postsLoginEndpoint_withCredentials") {
            let (svc, spy, _) = makeService(successRouter)
            _ = try await svc.login(.init(email: "test@example.com", password: "p"))
            let call = spy.calls.first { $0.path == "/auth/login" }
            s.expectNotNil(call)
            s.expectEqual(call?.method, .post)
            let creds = try JSONDecoder().decode(Credentials.self, from: call!.body!)
            s.expectEqual(creds.email, "test@example.com")
        }

        await s.test("login_success_persistsToken_refreshToken_andUserBlob") {
            let router: SpyAPIClient.Router = { _, _, _ in
                (200, Data(#"""
                {"success":true,"token":"TKN","refresh_token":"RFR",
                 "user":{"id":"1","email":"e@x.io","user_permissions":["*"]}}
                """#.utf8))
            }
            let (svc, _, store) = makeService(router)
            _ = try await svc.login(.init(email: "e@x.io", password: "p"))
            s.expectEqual(try store.loadToken(), "TKN")
            s.expectEqual(try store.loadRefreshToken(), "RFR")
            let blob = try store.loadUser()
            s.expectNotNil(blob)
            let u = try JSONDecoder().decode(AuthUser.self, from: blob!)
            s.expectEqual(u.email, "e@x.io")
        }

        await s.test("login_success_setsClientToken_andReturnsUser") {
            let (svc, spy, _) = makeService(successRouter)
            let user = try await svc.login(.init(email: "test@example.com", password: "p"))
            s.expectEqual(user.email, "test@example.com")
            s.expectEqual(spy.tokenHistory.last ?? nil, "TEST_TOKEN")
        }

        await s.test("login_failure_throwsAPIError_andPersistsNothing") {
            let router: SpyAPIClient.Router = { _, _, _ in
                (401, (try? loadFixture("login_error.json")) ?? Data())
            }
            let (svc, _, store) = makeService(router)
            await s.expectThrows {
                _ = try await svc.login(.init(email: "x", password: "y"))
            }
            s.expectNil(try store.loadToken())
            s.expectNil(try store.loadUser())
        }

        await s.test("logout_callsLogoutEndpoint") {
            let (svc, spy, _) = makeService(successRouter)
            await svc.logout()
            s.expect(spy.calls.contains { $0.path == "/auth/logout" && $0.method == .post })
        }

        await s.test("logout_clearsStore_andClientToken") {
            let (svc, spy, store) = makeService(successRouter)
            try store.saveToken("old")
            await svc.logout()
            s.expectNil(try store.loadToken())
            s.expectEqual(spy.tokenHistory.last ?? "x", String?.none)
        }

        await s.test("logout_clearsLocalState_evenWhenEndpointThrows") {
            let router: SpyAPIClient.Router = { _, _, _ in (500, Data()) }
            let (svc, _, store) = makeService(router)
            try store.saveToken("old")
            await svc.logout()
            s.expectNil(try store.loadToken())
        }

        await s.test("restore_withPersistedToken_returnsAuthenticatedUser") {
            let (svc, spy, store) = makeService(successRouter)
            try store.saveToken("T")
            try store.saveUser(Data(#"{"id":"1","email":"e@x.io"}"#.utf8))
            let u = svc.restore()
            s.expectEqual(u?.email, "e@x.io")
            s.expectEqual(spy.tokenHistory.last ?? nil, "T")
        }

        await s.test("restore_withCorruptUserBlob_returnsNil_butSetsClientToken") {
            let (svc, spy, store) = makeService(successRouter)
            try store.saveToken("T")
            try store.saveUser(Data("not json".utf8))
            s.expectNil(svc.restore())
            s.expectEqual(spy.tokenHistory.last ?? nil, "T")
        }

        await s.test("restore_withNoToken_returnsSignedOut") {
            let (svc, _, _) = makeService(successRouter)
            s.expectNil(svc.restore())
        }

        await s.test("fetchProfile_getsProfileEndpoint_returnsDecodedUser") {
            let (svc, spy, _) = makeService(successRouter)
            let u = try await svc.fetchProfile()
            s.expectEqual(u.email, "test@example.com")
            s.expect(spy.calls.contains { $0.path == "/user/profile" && $0.method == .get })
        }

        await s.test("endpointPaths_defaultTo_webValues_exceptProfile") {
            let e = AuthEndpoints()
            s.expectEqual(e.login, "/auth/login")
            s.expectEqual(e.logout, "/auth/logout")
            s.expectEqual(e.refresh, "/auth/refresh")
            s.expectEqual(e.profile, "/user/profile")
        }

        await s.test("endpointPaths_overridableViaConfig") {
            let spy = SpyAPIClient { path, _, _ in
                path == "/v2/signin"
                    ? (200, Data(#"{"success":true,"token":"t","user":{"id":"1","email":"e@x"}}"#.utf8))
                    : (404, Data())
            }
            let svc = DefaultAuthService(
                client: spy, store: InMemoryTokenStore(),
                endpoints: AuthEndpoints(login: "/v2/signin"))
            _ = try await svc.login(.init(email: "e@x", password: "p"))
            s.expect(spy.calls.contains { $0.path == "/v2/signin" })
        }

        await s.test("refreshAccessToken_throwsNotImplemented_deferredToSprint02") {
            let (svc, _, _) = makeService(successRouter)
            do {
                _ = try await svc.refreshAccessToken()
                s.expect(false, "should throw")
            } catch {
                if case .notImplemented = (error as? APIError) { s.expect(true) }
                else { s.expect(false, "wrong error: \(error)") }
            }
        }
    }
}
