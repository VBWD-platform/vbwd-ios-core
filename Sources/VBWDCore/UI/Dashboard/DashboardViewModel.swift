import Foundation
import Combine

/// Generic user dashboard logic. Port of `Dashboard.vue`:
/// profile summary always; token/invoice cards gated by `user_permissions`
/// via `PermissionEvaluator` (DRY — same rule as the rest of the SDK);
/// per-card data fetched concurrently, individual failures tolerated (web
/// `Promise.all` + per-card `.catch`).
@MainActor
public final class DashboardViewModel: ObservableObject {
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var invoices: [Invoice] = []
    @Published public private(set) var tokenTransactions: [TokenTransaction] = []
    @Published public private(set) var tokenBalance: Double = 0

    private let user: AuthUser
    private let api: APIClient
    private let endpoints: DashboardEndpoints
    private let evaluator: PermissionEvaluator
    private let components: ComponentRegistry?

    public init(user: AuthUser,
                api: APIClient,
                endpoints: DashboardEndpoints = DashboardEndpoints(),
                evaluator: PermissionEvaluator = PermissionEvaluator(),
                components: ComponentRegistry? = nil) {
        self.user = user
        self.api = api
        self.endpoints = endpoints
        self.evaluator = evaluator
        self.components = components
    }

    /// Plugin-contributed `Dashboard*` widgets, in registration order, shown
    /// after the core cards (port of `Dashboard.vue:226-234`). Reuses the
    /// single `Dashboard*` filter in `ComponentRegistry` (DRY).
    public var pluginWidgets: [(name: String, factory: ComponentFactory)] {
        components?.dashboardComponents() ?? []
    }

    // MARK: Profile (sourced from the authenticated user — web login parity)

    public var userName: String { user.name ?? "User" }
    public var userEmail: String { user.email }

    public var userInitials: String {
        let parts = userName.split(separator: " ")
        if parts.count >= 2 {
            return (parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return userName.prefix(2).uppercased()
    }

    // MARK: Permission-gated cards

    private var grantedPermissions: [String] { user.userPermissions ?? [] }

    public var showTokenCard: Bool {
        evaluator.has("subscription.tokens.view", in: grantedPermissions)
    }
    public var showInvoicesCard: Bool {
        evaluator.has("subscription.invoices.view", in: grantedPermissions)
    }

    public var recentInvoices: [Invoice] { Array(invoices.prefix(5)) }

    // MARK: Load

    public func load() async {
        isLoading = true
        errorMessage = nil

        async let inv = fetchInvoices()
        async let bal = fetchBalance()
        async let txns = fetchTransactions()
        let (i, b, t) = await (inv, bal, txns)

        invoices = i
        tokenBalance = b
        tokenTransactions = t
        isLoading = false
    }

    public func retry() async { await load() }

    // Per-card fetches never throw — a failed card is empty, the screen stays
    // (web `.catch(() => …)` behaviour).
    private func fetchInvoices() async -> [Invoice] {
        let r: InvoicesResponse? = try? await api.get(endpoints.invoices)
        return r?.invoices ?? []
    }
    private func fetchBalance() async -> Double {
        let r: TokenBalanceResponse? = try? await api.get(endpoints.tokenBalance)
        return r?.balance ?? 0
    }
    private func fetchTransactions() async -> [TokenTransaction] {
        let r: TokenTransactionsResponse? = try? await api.get(endpoints.tokenTransactions)
        return r?.transactions ?? []
    }
}
