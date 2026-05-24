import Foundation
import VBWDCore
import VBWDCoreTestKit

func registerSessionUISuites(_ runner: TestRunner) {

    // MARK: S7 — AuthSession
    runner.suite("S7 AuthSession") { s in
        await s.test("start_withRestoredUser_publishesAuthenticated") { @MainActor in
            let svc = SpyAuthService()
            svc.restoreUser = Fixtures.user()
            let session = AuthSession(service: svc)
            session.start()
            s.expectEqual(session.state, .authenticated(Fixtures.user()))
            s.expect(session.isAuthenticated)
        }
        await s.test("start_withNoToken_publishesSignedOut") { @MainActor in
            let session = AuthSession(service: SpyAuthService())
            session.start()
            s.expectEqual(session.state, .signedOut)
            s.expect(!session.isAuthenticated)
        }
        await s.test("signIn_success_publishesAuthenticated") { @MainActor in
            let svc = SpyAuthService()
            svc.loginResult = .success(Fixtures.user(name: "Ann"))
            let session = AuthSession(service: svc)
            await session.signIn(email: "e@x", password: "p")
            s.expectEqual(svc.loginCalls, 1)
            s.expectEqual(session.currentUser?.name, "Ann")
        }
        await s.test("signIn_failure_publishesErrorState") { @MainActor in
            let svc = SpyAuthService()
            svc.loginResult = .failure(APIError.http(status: 401, message: "Invalid credentials"))
            let session = AuthSession(service: svc)
            await session.signIn(email: "e@x", password: "bad")
            s.expectEqual(session.state, .error("Invalid credentials"))
            s.expect(!session.isAuthenticated)
        }
        await s.test("signOut_callsServiceLogout_andPublishesSignedOut") { @MainActor in
            let svc = SpyAuthService()
            svc.loginResult = .success(Fixtures.user())
            let session = AuthSession(service: svc)
            await session.signIn(email: "e", password: "p")
            await session.signOut()
            s.expect(svc.logoutCalled)
            s.expectEqual(session.state, .signedOut)
        }
        await s.test("isAuthenticated_trueOnly_whenAuthenticated") { @MainActor in
            let session = AuthSession(service: SpyAuthService())
            s.expect(!session.isAuthenticated)
        }
    }

    // MARK: S8 — LoginViewModel
    runner.suite("S8 LoginViewModel") { s in
        @MainActor
        func makeVM(_ result: Result<AuthUser, Error>) -> (LoginViewModel, SpyAuthService) {
            let svc = SpyAuthService()
            svc.loginResult = result
            return (LoginViewModel(session: AuthSession(service: svc)), svc)
        }

        await s.test("canSubmit_false_whenEmailEmpty") { @MainActor in
            let (vm, _) = makeVM(.success(Fixtures.user()))
            vm.password = "p"
            s.expect(!vm.canSubmit)
        }
        await s.test("canSubmit_false_whenPasswordEmpty") { @MainActor in
            let (vm, _) = makeVM(.success(Fixtures.user()))
            vm.email = "e@x"
            s.expect(!vm.canSubmit)
        }
        await s.test("canSubmit_true_whenBothPresent") { @MainActor in
            let (vm, _) = makeVM(.success(Fixtures.user()))
            vm.email = "e@x"; vm.password = "p"
            s.expect(vm.canSubmit)
        }
        await s.test("submit_success_clearsLoading_andNoError") { @MainActor in
            let (vm, svc) = makeVM(.success(Fixtures.user()))
            vm.email = "e@x"; vm.password = "p"
            await vm.submit()
            s.expectEqual(svc.loginCalls, 1)
            s.expect(!vm.isLoading)
            s.expectNil(vm.errorMessage)
        }
        await s.test("submit_failure_setsErrorMessage_andClearsLoading") { @MainActor in
            let (vm, _) = makeVM(.failure(APIError.http(status: 401, message: "Invalid credentials")))
            vm.email = "e@x"; vm.password = "bad"
            await vm.submit()
            s.expectEqual(vm.errorMessage, "Invalid credentials")
            s.expect(!vm.isLoading)
        }
        await s.test("submit_whenCannotSubmit_doesNothing") { @MainActor in
            let (vm, svc) = makeVM(.success(Fixtures.user()))
            await vm.submit() // empty fields
            s.expectEqual(svc.loginCalls, 0)
        }
    }

    // MARK: S9 — DashboardViewModel
    runner.suite("S9 DashboardViewModel") { s in
        nonisolated(unsafe) let okRouter: SpyAPIClient.Router = { path, _, _ in
            if path == "/user/invoices" {
                return (200, Data(#"""
                {"invoices":[
                  {"id":"1","invoice_number":"INV-1","amount":"10","status":"paid"},
                  {"id":"2","invoice_number":"INV-2","amount":"20","status":"paid"},
                  {"id":"3","invoice_number":"INV-3","amount":"30","status":"paid"},
                  {"id":"4","invoice_number":"INV-4","amount":"40","status":"paid"},
                  {"id":"5","invoice_number":"INV-5","amount":"50","status":"paid"},
                  {"id":"6","invoice_number":"INV-6","amount":"60","status":"paid"}
                ]}
                """#.utf8))
            }
            if path == "/user/tokens/balance" {
                return (200, Data(#"{"balance":42}"#.utf8))
            }
            if path.hasPrefix("/user/tokens/transactions") {
                return (200, Data(#"{"transactions":[{"id":"t1","amount":5,"transaction_type":"credit"}]}"#.utf8))
            }
            return (404, Data())
        }

        await s.test("load_fetchesInvoices_balance_transactions_concurrently") { @MainActor in
            let spy = SpyAPIClient(router: okRouter)
            let vm = DashboardViewModel(user: Fixtures.user(), api: spy)
            await vm.load()
            let paths = Set(spy.calls.map { $0.path })
            s.expect(paths.contains("/user/invoices"))
            s.expect(paths.contains("/user/tokens/balance"))
            s.expect(paths.contains { $0.hasPrefix("/user/tokens/transactions") })
            s.expectEqual(vm.tokenBalance, 42)
            s.expectEqual(vm.tokenTransactions.count, 1)
            s.expect(!vm.isLoading)
        }

        await s.test("load_invoiceFailure_doesNotFailScreen") { @MainActor in
            let router: SpyAPIClient.Router = { path, m, b in
                path == "/user/invoices" ? (500, Data()) : okRouter(path, m, b)
            }
            let vm = DashboardViewModel(user: Fixtures.user(), api: SpyAPIClient(router: router))
            await vm.load()
            s.expect(vm.invoices.isEmpty)
            s.expectEqual(vm.tokenBalance, 42)      // other cards still loaded
            s.expectNil(vm.errorMessage)
            s.expect(!vm.isLoading)
        }

        await s.test("tokenCard_visible_onlyWhen_subscription_tokens_view") { @MainActor in
            let off = DashboardViewModel(user: Fixtures.user(permissions: []),
                                         api: SpyAPIClient())
            let on = DashboardViewModel(
                user: Fixtures.user(permissions: ["subscription.tokens.view"]),
                api: SpyAPIClient())
            s.expect(!off.showTokenCard)
            s.expect(on.showTokenCard)
        }

        await s.test("invoicesCard_visible_onlyWhen_subscription_invoices_view") { @MainActor in
            let off = DashboardViewModel(user: Fixtures.user(permissions: []),
                                         api: SpyAPIClient())
            let on = DashboardViewModel(
                user: Fixtures.user(permissions: ["subscription.invoices.view"]),
                api: SpyAPIClient())
            s.expect(!off.showInvoicesCard)
            s.expect(on.showInvoicesCard)
        }

        await s.test("userInitials_twoWordName_returnsTwoUppercaseInitials") { @MainActor in
            let vm = DashboardViewModel(user: Fixtures.user(name: "Jane Doe"),
                                        api: SpyAPIClient())
            s.expectEqual(vm.userInitials, "JD")
        }

        await s.test("userInitials_singleName_returnsFirstTwoCharsUppercase") { @MainActor in
            let vm = DashboardViewModel(user: Fixtures.user(name: "ada"),
                                        api: SpyAPIClient())
            s.expectEqual(vm.userInitials, "AD")
        }

        await s.test("recentInvoices_limitedToFirstFive") { @MainActor in
            let vm = DashboardViewModel(user: Fixtures.user(), api: SpyAPIClient(router: okRouter))
            await vm.load()
            s.expectEqual(vm.recentInvoices.count, 5)
            s.expectEqual(vm.invoices.count, 6)
        }

        await s.test("retry_reloadsData") { @MainActor in
            let spy = SpyAPIClient(router: okRouter)
            let vm = DashboardViewModel(user: Fixtures.user(), api: spy)
            await vm.load()
            let firstCount = spy.calls.count
            await vm.retry()
            s.expect(spy.calls.count > firstCount)
        }
    }
}
