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
            let c = SDKContainer(tokenStore: InMemoryTokenStore())
            s.expectEqual(c.config.baseURL.absoluteString,
                          "https://vbwd.cc/api/v1")
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
}
