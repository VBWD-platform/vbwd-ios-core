import Foundation
import SwiftUI
import VBWDCore
import VBWDCoreTestKit

func registerCartAndCheckoutSourceSuites(_ runner: TestRunner) {

    // MARK: S6h — Cart

    runner.suite("S6h Cart") { s in

        await s.test("add_insertsNewItem") { @MainActor in
            let cart = Cart()
            let item = CartItem(type: "token_bundle", id: "b1", name: "Starter",
                                price: 9.99, currency: "USD")
            cart.add(item)
            s.expectEqual(cart.items.count, 1)
            s.expectEqual(cart.items.first?.id, "b1")
        }

        await s.test("add_incrementsQuantityForSameId") { @MainActor in
            let cart = Cart()
            let item = CartItem(type: "token_bundle", id: "b1", name: "Starter",
                                price: 9.99, currency: "USD")
            cart.add(item)
            cart.add(item)
            s.expectEqual(cart.items.count, 1)
            s.expectEqual(cart.items.first?.quantity, 2)
        }

        await s.test("remove_deletesItem") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "A", price: 1))
            cart.add(CartItem(type: "token_bundle", id: "b2", name: "B", price: 2))
            cart.remove(id: "b1")
            s.expectEqual(cart.items.count, 1)
            s.expectEqual(cart.items.first?.id, "b2")
        }

        await s.test("updateQuantity_setsQuantity") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "A", price: 5))
            cart.updateQuantity(id: "b1", quantity: 3)
            s.expectEqual(cart.items.first?.quantity, 3)
        }

        await s.test("updateQuantity_zeroRemovesItem") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "A", price: 5))
            cart.updateQuantity(id: "b1", quantity: 0)
            s.expect(cart.items.isEmpty)
        }

        await s.test("clear_emptiesCart") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "a", id: "1", name: "X", price: 1))
            cart.add(CartItem(type: "b", id: "2", name: "Y", price: 2))
            cart.clear()
            s.expect(cart.isEmpty)
        }

        await s.test("itemsOfType_filtersCorrectly") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "T1", price: 10))
            cart.add(CartItem(type: "subscription", id: "s1", name: "S1", price: 20))
            cart.add(CartItem(type: "token_bundle", id: "b2", name: "T2", price: 30))
            let bundles = cart.items(ofType: "token_bundle")
            s.expectEqual(bundles.count, 2)
            let subs = cart.items(ofType: "subscription")
            s.expectEqual(subs.count, 1)
        }

        await s.test("total_sumsCorrectly") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "a", id: "1", name: "X", price: 10, quantity: 2))
            cart.add(CartItem(type: "a", id: "2", name: "Y", price: 5, quantity: 1))
            s.expect(abs(cart.total - 25.0) < 0.01, "expected 25.0, got \(cart.total)")
        }

        await s.test("itemCount_sumsQuantities") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "a", id: "1", name: "X", price: 1, quantity: 3))
            cart.add(CartItem(type: "a", id: "2", name: "Y", price: 1, quantity: 2))
            s.expectEqual(cart.itemCount, 5)
        }

        await s.test("isEmpty_trueWhenEmpty") { @MainActor in
            let cart = Cart()
            s.expect(cart.isEmpty)
        }

        await s.test("isEmpty_falseWhenHasItems") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "a", id: "1", name: "X", price: 1))
            s.expect(!cart.isEmpty)
        }
    }

    // MARK: S6i — TokenBundle.toCartItem

    runner.suite("S6i TokenBundle.toCartItem") { s in

        await s.test("convertsCorrectly") { @MainActor in
            let bundle = try! JSONDecoder().decode(TokenBundle.self, from: Data(#"""
            {"id":"b1","name":"Starter","slug":"starter","description":"100 tokens",
             "token_amount":100,"price":"9.99","currency":"USD","is_active":true,"sort_order":1}
            """#.utf8))
            let item = bundle.toCartItem()
            s.expectEqual(item.type, "token_bundle")
            s.expectEqual(item.id, "b1")
            s.expectEqual(item.name, "Starter")
            s.expect(abs(item.price - 9.99) < 0.01)
            s.expectEqual(item.quantity, 1)
            s.expectEqual(item.currency, "USD")
            s.expectEqual(item.metadata["token_amount"], "100")
        }
    }

    // MARK: S6j — CheckoutSourceRegistry

    runner.suite("S6j CheckoutSourceRegistry") { s in

        await s.test("register_addsSource") { @MainActor in
            let registry = CheckoutSourceRegistry()
            let source = StubCheckoutSource(id: "test")
            registry.register(source)
            s.expectNotNil(registry.get(id: "test"))
        }

        await s.test("unregister_removesSource") { @MainActor in
            let registry = CheckoutSourceRegistry()
            registry.register(StubCheckoutSource(id: "test"))
            registry.unregister(id: "test")
            s.expectNil(registry.get(id: "test"))
        }

        await s.test("register_replacesSameId") { @MainActor in
            let registry = CheckoutSourceRegistry()
            let s1 = StubCheckoutSource(id: "x", matchResult: false)
            let s2 = StubCheckoutSource(id: "x", matchResult: true)
            registry.register(s1)
            registry.register(s2)
            s.expectEqual(registry.all.count, 1)
            let ctx = CheckoutContext()
            s.expectNotNil(registry.find(ctx))
        }

        await s.test("find_returnsHighestPriority") { @MainActor in
            let registry = CheckoutSourceRegistry()
            let low = StubCheckoutSource(id: "low", priorityValue: 0)
            let high = StubCheckoutSource(id: "high", priorityValue: 10)
            registry.register(low)
            registry.register(high)
            let found = registry.find(CheckoutContext())
            s.expectEqual(found?.id, "high")
        }

        await s.test("find_returnsNilWhenNoMatch") { @MainActor in
            let registry = CheckoutSourceRegistry()
            registry.register(StubCheckoutSource(id: "a", matchResult: false))
            let found = registry.find(CheckoutContext())
            s.expectNil(found)
        }
    }

    // MARK: S6k — TokenBundleCheckoutSource

    runner.suite("S6k TokenBundleCheckoutSource") { s in

        nonisolated(unsafe) let checkoutRouter: SpyAPIClient.Router = { path, method, body in
            if path == "/user/checkout" && method == .post {
                return (200, Data(#"{"invoice":{"id":"inv-1","invoice_number":"INV-1","status":"pending","amount":"9.99","currency":"USD"},"message":"OK"}"#.utf8))
            }
            return (404, Data())
        }

        await s.test("matches_trueWhenCartHasTokenBundles") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "T", price: 10))
            let source = TokenBundleCheckoutSource(api: SpyAPIClient(), cart: cart)
            s.expect(source.matches(CheckoutContext()))
        }

        await s.test("matches_falseWhenCartEmpty") { @MainActor in
            let cart = Cart()
            let source = TokenBundleCheckoutSource(api: SpyAPIClient(), cart: cart)
            s.expect(!source.matches(CheckoutContext()))
        }

        await s.test("matches_trueWhenSourceHintIsTokenBundle") { @MainActor in
            let cart = Cart()
            let source = TokenBundleCheckoutSource(api: SpyAPIClient(), cart: cart)
            s.expect(source.matches(CheckoutContext(source: "token_bundle")))
        }

        await s.test("matches_falseWhenSourceHintIsOther") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "T", price: 10))
            let source = TokenBundleCheckoutSource(api: SpyAPIClient(), cart: cart)
            s.expect(!source.matches(CheckoutContext(source: "subscription")))
        }

        await s.test("load_populatesLineItems") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "A", price: 10))
            cart.add(CartItem(type: "subscription", id: "s1", name: "S", price: 20))
            let source = TokenBundleCheckoutSource(api: SpyAPIClient(), cart: cart)
            try! await source.load(CheckoutContext())
            s.expectEqual(source.lineItems().count, 1)
            s.expectEqual(source.lineItems().first?.id, "b1")
        }

        await s.test("orderTotal_sumsTokenBundleItems") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "A", price: 9.99))
            cart.add(CartItem(type: "token_bundle", id: "b2", name: "B", price: 39.99))
            let source = TokenBundleCheckoutSource(api: SpyAPIClient(), cart: cart)
            try! await source.load(CheckoutContext())
            s.expect(abs(source.orderTotal() - 49.98) < 0.01)
        }

        await s.test("submit_postsCorrectRequest") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "A", price: 9.99, currency: "USD"))
            let spy = SpyAPIClient(router: checkoutRouter)
            let source = TokenBundleCheckoutSource(api: spy, cart: cart)
            try! await source.load(CheckoutContext())
            let result = try! await source.submit(paymentMethodCode: "stripe")
            s.expectEqual(result.invoiceId, "inv-1")
            s.expectEqual(result.status, "pending")
            let postCalls = spy.calls.filter { $0.method == .post }
            s.expectEqual(postCalls.count, 1)
            s.expectEqual(postCalls.first?.path, "/user/checkout")
        }

        await s.test("reset_clearsLineItems") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "A", price: 10))
            let source = TokenBundleCheckoutSource(api: SpyAPIClient(), cart: cart)
            try! await source.load(CheckoutContext())
            s.expectEqual(source.lineItems().count, 1)
            source.reset()
            s.expect(source.lineItems().isEmpty)
        }
    }

    // MARK: S6l — CheckoutViewModel orchestrator

    runner.suite("S6l CheckoutViewModel orchestrator") { s in

        nonisolated(unsafe) let paymentMethodsRouter: SpyAPIClient.Router = { path, _, _ in
            if path == "/settings/payment-methods" {
                return (200, Data(#"""
                {"methods":[
                  {"id":"pm1","code":"stripe","name":"Stripe","icon":null,"is_active":true},
                  {"id":"pm2","code":"invoice","name":"Invoice","icon":null,"is_active":true}
                ]}
                """#.utf8))
            }
            if path == "/user/checkout" {
                return (200, Data(#"{"invoice":{"id":"inv-1","invoice_number":"INV-1","status":"pending","amount":"9.99","currency":"USD"},"message":"OK"}"#.utf8))
            }
            return (404, Data())
        }

        await s.test("loadForContext_findsSourceAndLoadsItems") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "T", price: 9.99, currency: "USD"))
            let spy = SpyAPIClient(router: paymentMethodsRouter)
            let registry = CheckoutSourceRegistry()
            let source = TokenBundleCheckoutSource(api: spy, cart: cart)
            registry.register(source)
            let vm = CheckoutViewModel(
                api: spy, context: CheckoutContext(),
                cart: cart, checkoutSources: registry)
            await vm.loadForContext()
            s.expectEqual(vm.lineItems.count, 1)
            s.expectEqual(vm.lineItems.first?.id, "b1")
            s.expect(!vm.isLoading)
            s.expectNotNil(vm.activeSource)
        }

        await s.test("loadForContext_loadsPaymentMethods") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "T", price: 9.99))
            let spy = SpyAPIClient(router: paymentMethodsRouter)
            let registry = CheckoutSourceRegistry()
            registry.register(TokenBundleCheckoutSource(api: spy, cart: cart))
            let vm = CheckoutViewModel(
                api: spy, context: CheckoutContext(),
                cart: cart, checkoutSources: registry)
            await vm.loadForContext()
            s.expectEqual(vm.paymentMethods.count, 2)
        }

        await s.test("submit_delegatesToSourceAndSetsConfirmation") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "T", price: 9.99, currency: "USD"))
            let spy = SpyAPIClient(router: paymentMethodsRouter)
            let registry = CheckoutSourceRegistry()
            registry.register(TokenBundleCheckoutSource(api: spy, cart: cart))
            let vm = CheckoutViewModel(
                api: spy, context: CheckoutContext(),
                cart: cart, checkoutSources: registry)
            await vm.loadForContext()
            vm.selectedMethodId = "invoice"
            await vm.submit()
            // No payment action handler for "invoice" → goes to confirmation
            if case .confirmation(let result) = vm.phase {
                s.expectEqual(result.invoiceId, "inv-1")
            } else {
                s.expect(false, "expected confirmation phase")
            }
            s.expect(!vm.isSubmitting)
        }

        await s.test("submit_withoutSource_doesNothing") { @MainActor in
            let cart = Cart()
            let spy = SpyAPIClient(router: paymentMethodsRouter)
            let registry = CheckoutSourceRegistry()
            // No sources registered, cart empty → no source matched
            let vm = CheckoutViewModel(
                api: spy, context: CheckoutContext(source: "nonexistent"),
                cart: cart, checkoutSources: registry)
            await vm.loadForContext()
            vm.selectedMethodId = "stripe"
            await vm.submit()
            s.expectNil(vm.checkoutResult)
        }

        await s.test("orderTotal_computedFromSource") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "A", price: 9.99))
            cart.add(CartItem(type: "token_bundle", id: "b2", name: "B", price: 39.99))
            let spy = SpyAPIClient(router: paymentMethodsRouter)
            let registry = CheckoutSourceRegistry()
            registry.register(TokenBundleCheckoutSource(api: spy, cart: cart))
            let vm = CheckoutViewModel(
                api: spy, context: CheckoutContext(),
                cart: cart, checkoutSources: registry)
            await vm.loadForContext()
            s.expect(abs(vm.orderTotal - 49.98) < 0.01, "expected ~49.98, got \(vm.orderTotal)")
        }

        await s.test("canSubmit_falseWhenNoMethodSelected") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "T", price: 9.99))
            let spy = SpyAPIClient(router: paymentMethodsRouter)
            let registry = CheckoutSourceRegistry()
            registry.register(TokenBundleCheckoutSource(api: spy, cart: cart))
            let vm = CheckoutViewModel(
                api: spy, context: CheckoutContext(),
                cart: cart, checkoutSources: registry)
            await vm.loadForContext()
            s.expect(!vm.canSubmit)
        }

        await s.test("canSubmit_trueWhenMethodSelected") { @MainActor in
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "T", price: 9.99))
            let spy = SpyAPIClient(router: paymentMethodsRouter)
            let registry = CheckoutSourceRegistry()
            registry.register(TokenBundleCheckoutSource(api: spy, cart: cart))
            let vm = CheckoutViewModel(
                api: spy, context: CheckoutContext(),
                cart: cart, checkoutSources: registry)
            await vm.loadForContext()
            vm.selectedMethodId = "stripe"
            s.expect(vm.canSubmit)
        }
    }
}

// MARK: - Test Double: StubCheckoutSource

@MainActor
private final class StubCheckoutSource: CheckoutSource {
    let id: String
    let priority: Int
    private let matchResult: Bool
    private var items: [CartItem] = []

    init(id: String, priorityValue: Int = 0, matchResult: Bool = true) {
        self.id = id
        self.priority = priorityValue
        self.matchResult = matchResult
    }

    func matches(_ ctx: CheckoutContext) -> Bool { matchResult }
    func load(_ ctx: CheckoutContext) async throws {
        items = [CartItem(type: "stub", id: "s1", name: "Stub", price: 10)]
    }
    func lineItems() -> [CartItem] { items }
    func orderTotal() -> Double { items.reduce(0) { $0 + $1.price } }
    func submit(paymentMethodCode: String?) async throws -> CheckoutResult {
        CheckoutResult(invoice: CheckoutInvoice(id: "inv-stub", status: "pending"),
                       message: "OK")
    }
    func reset() { items = [] }
    var summaryComponent: ComponentFactory? { nil }
}
