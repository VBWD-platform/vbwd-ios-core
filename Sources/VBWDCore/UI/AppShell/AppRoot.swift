import SwiftUI
import Combine

/// Top-level composed root: boots the plugin host, wraps content in burger menu,
/// shows Login (signed out) or Dashboard (signed in) with core cards + plugin
/// widgets. Sprint 03: adds BurgerMenuContainer and NavigationStack.
/// Sprint 04: adds ProfileEditView. Sprint 05: injects ThemeManager + environment.
@MainActor
public struct AppRoot: View {
    @ObservedObject private var session: AuthSession
    @ObservedObject private var host: PluginHost
    @ObservedObject private var themeManager: ThemeManager
    private let container: SDKContainer
    @State private var booted = false
    @State private var isReady = false
    @State private var showCartCheckout = false

    public init(container: SDKContainer,
                plugins: [Plugin],
                manifestLoader: PluginManifestLoader? = nil) {
        self.container = container
        self._session = ObservedObject(wrappedValue: container.session)
        self._themeManager = ObservedObject(wrappedValue: container.themeManager)
        let h = container.makePluginHost(plugins: plugins,
                                         manifestLoader: manifestLoader)
        self._host = ObservedObject(wrappedValue: h)
    }

    public var body: some View {
        BurgerMenuContainer {
            NavigationStack {
                Group {
                    if !isReady {
                        SplashView()
                    } else {
                        switch RootRouter.route(for: session.state) {
                        case .login:
                            LoginView(viewModel: container.makeLoginViewModel())
                        case .loading:
                            SplashView()
                        case let .dashboard(user):
                            routedContent(user: user)
                        }
                    }
                }
            }
        }
        .environment(\.appTheme, themeManager.currentTheme)
        .preferredColorScheme(themeManager.currentTheme.preferredColorScheme)
        .environmentObject(session)
        .environmentObject(host)
        .environmentObject(themeManager)
        .environmentObject(container.cart)
        .environment(\.showCartCheckout, $showCartCheckout)
        .sheet(isPresented: $showCartCheckout) {
            CartCheckoutContainer(checkoutViewModelFactory: {
                container.makeCheckoutViewModel(
                    context: CheckoutContext(isCart: true),
                    components: host.components,
                    events: host.sdk.events)
            })
            .environmentObject(container.cart)
            .environmentObject(host)
            .environment(\.appTheme, themeManager.currentTheme)
        }
        .onReceive(container.cart.$checkoutRequestCount.dropFirst()) { _ in
            showCartCheckout = true
        }
        .task {
            if !booted {
                booted = true
                await host.bootstrap()
                session.start()
                isReady = true
            }
        }
    }

    @ViewBuilder
    private func routedContent(user: AuthUser) -> some View {
        switch host.selectedRoute {
        case nil:
            DashboardView(viewModel: container.makeDashboardViewModel(
                user: user, components: host.components))
        case "/profile":
            ProfileEditView(viewModel: container.makeProfileViewModel(),
                            user: user)
        case "/settings":
            SettingsScreen()
        case "/store/tokens":
            TokensView(viewModel: container.makeTokensViewModel())
        case "/store/buy-tokens":
            BuyTokensView(
                viewModel: container.makeBuyTokensViewModel(),
                cart: container.cart
            )
        case "/billing/invoices":
            InvoicesView(viewModel: container.makeInvoicesViewModel())
        case let route? where route.hasPrefix("/billing/invoice/"):
            InvoiceDetailView(
                viewModel: container.makeInvoiceDetailViewModel(
                    invoiceId: String(route.dropFirst("/billing/invoice/".count))))
        case let route?:
            if let pluginRoute = host.routes.first(where: { r in
                r.path == route || (r.matchPrefix && route.hasPrefix(r.path))
            }) {
                pluginRoute.view()
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .modifier(MenuToolbar())
            } else {
                DashboardView(viewModel: container.makeDashboardViewModel(
                    user: user, components: host.components))
            }
        }
    }
}
