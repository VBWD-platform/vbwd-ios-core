import Foundation
import SwiftUI
import VBWDCore
import VBWDCoreTestKit

func registerCheckoutSuites(_ runner: TestRunner) {

    // MARK: S6c — BuyTokensViewModel + Bundles

    runner.suite("S6c BuyTokensViewModel") { s in

        nonisolated(unsafe) let okRouter: SpyAPIClient.Router = { path, _, _ in
            if path == "/token-bundles" {
                return (200, Data(#"""
                {"bundles":[
                  {"id":"b1","name":"Starter","slug":"starter","token_amount":100,"price":"9.99","currency":"USD","is_active":true,"sort_order":2},
                  {"id":"b2","name":"Pro","slug":"pro","token_amount":500,"price":"39.99","currency":"USD","is_active":true,"sort_order":1}
                ]}
                """#.utf8))
            }
            return (404, Data())
        }

        await s.test("load_fetchesBundles") { @MainActor in
            let spy = SpyAPIClient(router: okRouter)
            let vm = BuyTokensViewModel(api: spy)
            await vm.load()
            s.expectEqual(vm.bundles.count, 2)
            s.expect(!vm.isLoading)
        }

        await s.test("load_bundlesSortedBySortOrder") { @MainActor in
            let spy = SpyAPIClient(router: okRouter)
            let vm = BuyTokensViewModel(api: spy)
            await vm.load()
            // Pro (sort_order 1) should come before Starter (sort_order 2)
            s.expectEqual(vm.bundles.first?.name, "Pro")
            s.expectEqual(vm.bundles.last?.name, "Starter")
        }

        await s.test("load_failure_toleratedWithEmptyList") { @MainActor in
            let router: SpyAPIClient.Router = { _, _, _ in (500, Data()) }
            let vm = BuyTokensViewModel(api: SpyAPIClient(router: router))
            await vm.load()
            s.expect(vm.bundles.isEmpty)
            s.expect(!vm.isLoading)
        }

        await s.test("retry_reloadsData") { @MainActor in
            let spy = SpyAPIClient(router: okRouter)
            let vm = BuyTokensViewModel(api: spy)
            await vm.load()
            let firstCount = spy.calls.count
            await vm.retry()
            s.expect(spy.calls.count > firstCount)
        }

        await s.test("bundleConformsToCheckoutItem") { @MainActor in
            let spy = SpyAPIClient(router: okRouter)
            let vm = BuyTokensViewModel(api: spy)
            await vm.load()
            guard let bundle = vm.bundles.first else {
                s.expect(false, "no bundles loaded")
                return
            }
            let item: any CheckoutItem = bundle
            s.expectEqual(item.checkoutItemId, bundle.id)
            s.expectEqual(item.checkoutItemName, bundle.name)
            s.expectEqual(item.checkoutItemPrice, bundle.price)
            s.expectEqual(item.checkoutItemCurrency, "USD")
            s.expectEqual(item.checkoutItemQuantity, 1)
        }
    }

    // MARK: S6d — CheckoutViewModel

    runner.suite("S6d CheckoutViewModel") { s in

        nonisolated(unsafe) let paymentMethodsRouter: SpyAPIClient.Router = { path, _, _ in
            if path == "/settings/payment-methods" {
                return (200, Data(#"""
                {"methods":[
                  {"id":"pm1","code":"stripe","name":"Stripe","icon":null,"is_active":true},
                  {"id":"pm2","code":"paypal","name":"PayPal","icon":"dollarsign.circle.fill","is_active":true}
                ]}
                """#.utf8))
            }
            if path == "/user/checkout" {
                return (200, Data(#"{"invoice":{"id":"inv-123","invoice_number":"INV-TEST","status":"pending","amount":"49.98","currency":"USD"},"message":"Checkout created."}"#.utf8))
            }
            return (404, Data())
        }

        /// Helper: builds a CheckoutViewModel wired to a Cart with two token
        /// bundles (Starter $9.99 + Pro $39.99) and a TokenBundleCheckoutSource.
        @MainActor func makeVM(spy: SpyAPIClient,
                               components: ComponentRegistry? = nil) -> CheckoutViewModel {
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "Starter",
                              price: 9.99, currency: "USD"))
            cart.add(CartItem(type: "token_bundle", id: "b2", name: "Pro",
                              price: 39.99, currency: "USD"))
            let registry = CheckoutSourceRegistry()
            registry.register(TokenBundleCheckoutSource(api: spy, cart: cart))
            return CheckoutViewModel(
                api: spy, context: CheckoutContext(),
                cart: cart, checkoutSources: registry, components: components)
        }

        await s.test("loadPaymentMethods_fetchesFromAPI") { @MainActor in
            let spy = SpyAPIClient(router: paymentMethodsRouter)
            let vm = makeVM(spy: spy)
            await vm.loadForContext()
            s.expectEqual(vm.paymentMethods.count, 2)
            s.expectEqual(vm.paymentMethods.first?.code, "stripe")
            s.expect(!vm.isLoading)
        }

        await s.test("loadPaymentMethods_failure_toleratedWithEmptyList") { @MainActor in
            let router: SpyAPIClient.Router = { _, _, _ in (500, Data()) }
            let spy = SpyAPIClient(router: router)
            let vm = makeVM(spy: spy)
            await vm.loadPaymentMethods()
            s.expect(vm.paymentMethods.isEmpty)
            s.expect(!vm.isLoading)
        }

        await s.test("orderTotal_computedFromItems") { @MainActor in
            let spy = SpyAPIClient(router: paymentMethodsRouter)
            let vm = makeVM(spy: spy)
            await vm.loadForContext()
            // 9.99 + 39.99 = 49.98
            let total = vm.orderTotal
            s.expect(abs(total - 49.98) < 0.01, "expected ~49.98, got \(total)")
        }

        await s.test("currency_fromFirstItem") { @MainActor in
            let spy = SpyAPIClient(router: paymentMethodsRouter)
            let vm = makeVM(spy: spy)
            await vm.loadForContext()
            s.expectEqual(vm.currency, "USD")
        }

        await s.test("canSubmit_falseWhenNoMethodSelected") { @MainActor in
            let spy = SpyAPIClient(router: paymentMethodsRouter)
            let vm = makeVM(spy: spy)
            await vm.loadForContext()
            s.expect(!vm.canSubmit)
        }

        await s.test("canSubmit_trueWhenMethodSelected") { @MainActor in
            let spy = SpyAPIClient(router: paymentMethodsRouter)
            let vm = makeVM(spy: spy)
            await vm.loadForContext()
            vm.selectedMethodId = "stripe"
            s.expect(vm.canSubmit)
        }

        await s.test("submit_postsCheckoutRequest") { @MainActor in
            let spy = SpyAPIClient(router: paymentMethodsRouter)
            let vm = makeVM(spy: spy)
            await vm.loadForContext()
            vm.selectedMethodId = "stripe"
            await vm.submit()
            s.expectNotNil(vm.checkoutResult)
            s.expectEqual(vm.checkoutResult?.invoiceId, "inv-123")
            s.expectEqual(vm.checkoutResult?.status, "pending")
            s.expectNil(vm.errorMessage)
            s.expect(!vm.isSubmitting)
            // Verify POST was made to /user/checkout
            let postCalls = spy.calls.filter { $0.method == .post && $0.path == "/user/checkout" }
            s.expectEqual(postCalls.count, 1)
        }

        await s.test("submit_failure_setsErrorMessage") { @MainActor in
            let router: SpyAPIClient.Router = { path, method, body in
                if path == "/user/checkout" && method == .post {
                    return (400, Data(#"{"error":"Invalid checkout"}"#.utf8))
                }
                return paymentMethodsRouter(path, method, body)
            }
            let spy = SpyAPIClient(router: router)
            let vm = makeVM(spy: spy)
            await vm.loadForContext()
            vm.selectedMethodId = "stripe"
            await vm.submit()
            s.expectNil(vm.checkoutResult)
            s.expectNotNil(vm.errorMessage)
            s.expect(!vm.isSubmitting)
        }

        await s.test("submit_withoutSelectedMethod_doesNothing") { @MainActor in
            let spy = SpyAPIClient(router: paymentMethodsRouter)
            let vm = makeVM(spy: spy)
            await vm.loadForContext()
            // selectedMethodId is nil
            await vm.submit()
            s.expectNil(vm.checkoutResult)
            let postCalls = spy.calls.filter { $0.method == .post }
            s.expect(postCalls.isEmpty)
        }

        await s.test("isSubmitting_falseAfterSubmit") { @MainActor in
            let spy = SpyAPIClient(router: paymentMethodsRouter)
            let vm = makeVM(spy: spy)
            await vm.loadForContext()
            s.expect(!vm.isSubmitting)
            vm.selectedMethodId = "stripe"
            await vm.submit()
            s.expect(!vm.isSubmitting)
        }
    }

    // MARK: S6e — ComponentRegistry.checkoutComponents

    runner.suite("S6e ComponentRegistry.checkoutComponents") { s in

        await s.test("returnsOnlyCheckoutPrefixedComponents") { @MainActor in
            let registry = ComponentRegistry()
            registry.add("DashboardWeather") { AnyView(EmptyView()) }
            registry.add("CheckoutDiscount") { AnyView(EmptyView()) }
            registry.add("ProfileBio") { AnyView(EmptyView()) }
            registry.add("CheckoutShipping") { AnyView(EmptyView()) }

            let checkout = registry.checkoutComponents()
            s.expectEqual(checkout.count, 2)
            s.expectEqual(checkout[0].name, "CheckoutDiscount")
            s.expectEqual(checkout[1].name, "CheckoutShipping")
        }

        await s.test("emptyWhenNoCheckoutComponents") { @MainActor in
            let registry = ComponentRegistry()
            registry.add("DashboardWeather") { AnyView(EmptyView()) }
            let checkout = registry.checkoutComponents()
            s.expect(checkout.isEmpty)
        }

        await s.test("respectsRegistrationOrder") { @MainActor in
            let registry = ComponentRegistry()
            registry.add("CheckoutB") { AnyView(EmptyView()) }
            registry.add("CheckoutA") { AnyView(EmptyView()) }
            registry.add("CheckoutC") { AnyView(EmptyView()) }
            let names = registry.checkoutComponents().map(\.name)
            s.expectEqual(names, ["CheckoutB", "CheckoutA", "CheckoutC"])
        }
    }

    // MARK: S6f — ComponentRegistry.supportedPaymentMethodCodes

    runner.suite("S6f ComponentRegistry.supportedPaymentMethodCodes") { s in

        await s.test("extractsCodesFromPaymentMethodPrefix") { @MainActor in
            let registry = ComponentRegistry()
            registry.add("PaymentMethodStripe") { AnyView(EmptyView()) }
            registry.add("PaymentMethodInvoice") { AnyView(EmptyView()) }
            registry.add("CheckoutDiscount") { AnyView(EmptyView()) }
            let codes = registry.supportedPaymentMethodCodes()
            s.expectEqual(codes, Set(["stripe", "invoice"]))
        }

        await s.test("emptyWhenNoPaymentMethodComponents") { @MainActor in
            let registry = ComponentRegistry()
            registry.add("CheckoutShipping") { AnyView(EmptyView()) }
            let codes = registry.supportedPaymentMethodCodes()
            s.expect(codes.isEmpty)
        }

        await s.test("codeIsLowercased") { @MainActor in
            let registry = ComponentRegistry()
            registry.add("PaymentMethodPayPal") { AnyView(EmptyView()) }
            let codes = registry.supportedPaymentMethodCodes()
            s.expect(codes.contains("paypal"))
        }

        await s.test("paymentMethodDetail_returnsFactoryForMatchingCode") { @MainActor in
            let registry = ComponentRegistry()
            registry.add("PaymentMethodStripe") { AnyView(EmptyView()) }
            s.expectNotNil(registry.paymentMethodDetail(for: "stripe"))
        }

        await s.test("paymentMethodDetail_returnsNilForUnknownCode") { @MainActor in
            let registry = ComponentRegistry()
            registry.add("PaymentMethodStripe") { AnyView(EmptyView()) }
            s.expectNil(registry.paymentMethodDetail(for: "paypal"))
        }
    }

    // MARK: S6g — CheckoutViewModel filters by plugin support

    runner.suite("S6g CheckoutViewModel paymentMethod filtering") { s in

        nonisolated(unsafe) let allMethodsRouter: SpyAPIClient.Router = { path, _, _ in
            if path == "/settings/payment-methods" {
                return (200, Data(#"""
                {"methods":[
                  {"id":"pm1","code":"stripe","name":"Stripe","icon":null,"is_active":true},
                  {"id":"pm2","code":"paypal","name":"PayPal","icon":null,"is_active":true},
                  {"id":"pm3","code":"invoice","name":"Invoice","icon":null,"is_active":true}
                ]}
                """#.utf8))
            }
            return (404, Data())
        }

        /// Helper: builds a minimal CheckoutViewModel with one cart item.
        @MainActor func makeFilterVM(spy: SpyAPIClient,
                                     components: ComponentRegistry? = nil) -> CheckoutViewModel {
            let cart = Cart()
            cart.add(CartItem(type: "token_bundle", id: "b1", name: "Test",
                              price: 9.99, currency: "USD"))
            let registry = CheckoutSourceRegistry()
            registry.register(TokenBundleCheckoutSource(api: spy, cart: cart))
            return CheckoutViewModel(
                api: spy, context: CheckoutContext(),
                cart: cart, checkoutSources: registry, components: components)
        }

        await s.test("filtersToOnlyPluginSupportedMethods") { @MainActor in
            let spy = SpyAPIClient(router: allMethodsRouter)
            let components = ComponentRegistry()
            components.add("PaymentMethodStripe") { AnyView(EmptyView()) }
            components.add("PaymentMethodInvoice") { AnyView(EmptyView()) }
            let vm = makeFilterVM(spy: spy, components: components)
            await vm.loadPaymentMethods()
            s.expectEqual(vm.paymentMethods.count, 2)
            let codes = Set(vm.paymentMethods.map(\.code))
            s.expect(codes.contains("stripe"))
            s.expect(codes.contains("invoice"))
            s.expect(!codes.contains("paypal"))
        }

        await s.test("showsAllMethodsWhenNoPluginsRegistered") { @MainActor in
            let spy = SpyAPIClient(router: allMethodsRouter)
            let vm = makeFilterVM(spy: spy)
            await vm.loadPaymentMethods()
            s.expectEqual(vm.paymentMethods.count, 3)
        }

        await s.test("showsAllMethodsWhenComponentsNil") { @MainActor in
            let spy = SpyAPIClient(router: allMethodsRouter)
            let vm = makeFilterVM(spy: spy, components: nil)
            await vm.loadPaymentMethods()
            s.expectEqual(vm.paymentMethods.count, 3)
        }
    }
}
