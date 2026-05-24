import SwiftUI

/// App entry view. Auth guard (port of the web router): Login when signed out,
/// Dashboard when authenticated. Routing decision delegated to `RootRouter`.
public struct RootView: View {
    @ObservedObject private var session: AuthSession
    private let container: SDKContainer

    public init(container: SDKContainer) {
        self.container = container
        self._session = ObservedObject(wrappedValue: container.session)
    }

    public var body: some View {
        Group {
            switch RootRouter.route(for: session.state) {
            case .login:
                LoginView(viewModel: container.makeLoginViewModel())
            case .loading:
                ProgressView()
            case let .dashboard(user):
                DashboardView(viewModel: container.makeDashboardViewModel(user: user))
            }
        }
        .onAppear { session.start() }
    }
}
