import Foundation
import VBWDCore
import VBWDCoreTestKit

func registerStoreAndBillingSuites(_ runner: TestRunner) {

    // MARK: S6a — TokensViewModel

    runner.suite("S6a TokensViewModel") { s in

        nonisolated(unsafe) let okRouter: SpyAPIClient.Router = { path, _, _ in
            if path == "/user/tokens/balance" {
                return (200, Data(#"{"balance":99}"#.utf8))
            }
            if path.hasPrefix("/user/tokens/transactions") {
                return (200, Data(#"""
                {"transactions":[
                  {"id":"t1","amount":5,"transaction_type":"credit","created_at":"2026-01-01"},
                  {"id":"t2","amount":-3,"transaction_type":"debit","created_at":"2026-01-02"}
                ]}
                """#.utf8))
            }
            return (404, Data())
        }

        await s.test("load_fetchesBalance_andTransactions_concurrently") { @MainActor in
            let spy = SpyAPIClient(router: okRouter)
            let vm = TokensViewModel(api: spy)
            await vm.load()
            s.expectEqual(vm.balance, 99)
            s.expectEqual(vm.transactions.count, 2)
            s.expect(!vm.isLoading)
            s.expectNil(vm.errorMessage)
        }

        await s.test("load_balanceFailure_doesNotFailScreen") { @MainActor in
            let router: SpyAPIClient.Router = { path, m, b in
                path == "/user/tokens/balance" ? (500, Data()) : okRouter(path, m, b)
            }
            let vm = TokensViewModel(api: SpyAPIClient(router: router))
            await vm.load()
            s.expectEqual(vm.balance, 0)              // default on failure
            s.expectEqual(vm.transactions.count, 2)   // other card still loaded
            s.expect(!vm.isLoading)
        }

        await s.test("load_transactionsFailure_doesNotFailScreen") { @MainActor in
            let router: SpyAPIClient.Router = { path, m, b in
                path.hasPrefix("/user/tokens/transactions") ? (500, Data()) : okRouter(path, m, b)
            }
            let vm = TokensViewModel(api: SpyAPIClient(router: router))
            await vm.load()
            s.expectEqual(vm.balance, 99)
            s.expect(vm.transactions.isEmpty)
            s.expect(!vm.isLoading)
        }

        await s.test("retry_reloadsData") { @MainActor in
            let spy = SpyAPIClient(router: okRouter)
            let vm = TokensViewModel(api: spy)
            await vm.load()
            let firstCount = spy.calls.count
            await vm.retry()
            s.expect(spy.calls.count > firstCount)
        }

        await s.test("load_stripsLimitFromEndpoint") { @MainActor in
            let spy = SpyAPIClient(router: okRouter)
            let endpoints = DashboardEndpoints(
                tokenTransactions: "/user/tokens/transactions?limit=10")
            let vm = TokensViewModel(api: spy, endpoints: endpoints)
            await vm.load()
            // Should call without ?limit=10
            let txnPaths = spy.calls.filter { $0.path.hasPrefix("/user/tokens/transactions") }
            s.expect(!txnPaths.isEmpty)
            for call in txnPaths {
                s.expect(!call.path.contains("limit"))
            }
        }

        await s.test("isLoading_falseAfterLoad") { @MainActor in
            let vm = TokensViewModel(api: SpyAPIClient(router: okRouter))
            s.expect(!vm.isLoading)
            await vm.load()
            s.expect(!vm.isLoading)
        }
    }

    // MARK: S6b — InvoicesViewModel

    runner.suite("S6b InvoicesViewModel") { s in

        nonisolated(unsafe) let okRouter: SpyAPIClient.Router = { path, _, _ in
            if path == "/invoices/" {
                return (200, Data(#"""
                {"invoices":[
                  {"id":"1","invoice_number":"INV-1","invoiced_at":"2026-01-01","amount":"10.00","status":"paid"},
                  {"id":"2","invoice_number":"INV-2","invoiced_at":"2026-01-15","amount":"20.00","status":"pending"},
                  {"id":"3","invoice_number":"INV-3","invoiced_at":"2026-02-01","amount":"30.00","status":"paid"}
                ]}
                """#.utf8))
            }
            return (404, Data())
        }

        await s.test("load_fetchesAllInvoices") { @MainActor in
            let spy = SpyAPIClient(router: okRouter)
            let vm = InvoicesViewModel(api: spy)
            await vm.load()
            s.expectEqual(vm.invoices.count, 3)
            s.expectEqual(vm.invoices.first?.invoiceNumber, "INV-1")
            s.expect(!vm.isLoading)
            s.expectNil(vm.errorMessage)
        }

        await s.test("load_invoiceFailure_toleratedWithEmptyList") { @MainActor in
            let router: SpyAPIClient.Router = { _, _, _ in (500, Data()) }
            let vm = InvoicesViewModel(api: SpyAPIClient(router: router))
            await vm.load()
            s.expect(vm.invoices.isEmpty)
            s.expect(!vm.isLoading)
        }

        await s.test("retry_reloadsData") { @MainActor in
            let spy = SpyAPIClient(router: okRouter)
            let vm = InvoicesViewModel(api: spy)
            await vm.load()
            let firstCount = spy.calls.count
            await vm.retry()
            s.expect(spy.calls.count > firstCount)
        }

        await s.test("isLoading_falseAfterLoad") { @MainActor in
            let vm = InvoicesViewModel(api: SpyAPIClient(router: okRouter))
            s.expect(!vm.isLoading)
            await vm.load()
            s.expect(!vm.isLoading)
        }
    }
}
