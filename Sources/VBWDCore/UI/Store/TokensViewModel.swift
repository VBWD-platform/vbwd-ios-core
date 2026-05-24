import Foundation

/// Token balance + transaction history. Dedicated screen counterpart of the
/// dashboard's token card (same endpoints, no limit). Pattern mirrors
/// `DashboardViewModel`: concurrent fetch, per-card failure tolerance.
@MainActor
public final class TokensViewModel: ObservableObject {
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var balance: Double = 0
    @Published public private(set) var transactions: [TokenTransaction] = []

    private let api: APIClient
    private let endpoints: DashboardEndpoints

    public init(api: APIClient, endpoints: DashboardEndpoints = DashboardEndpoints()) {
        self.api = api
        self.endpoints = endpoints
    }

    public func load() async {
        isLoading = true
        errorMessage = nil

        async let bal = fetchBalance()
        async let txns = fetchTransactions()
        let (b, t) = await (bal, txns)

        balance = b
        transactions = t
        isLoading = false
    }

    public func retry() async { await load() }

    // MARK: - Private

    private func fetchBalance() async -> Double {
        let r: TokenBalanceResponse? = try? await api.get(endpoints.tokenBalance)
        return r?.balance ?? 0
    }

    private func fetchTransactions() async -> [TokenTransaction] {
        // Strip the dashboard's ?limit=10 to get full history.
        let path = endpoints.tokenTransactions
            .components(separatedBy: "?").first ?? endpoints.tokenTransactions
        let r: TokenTransactionsResponse? = try? await api.get(path)
        return r?.transactions ?? []
    }
}
