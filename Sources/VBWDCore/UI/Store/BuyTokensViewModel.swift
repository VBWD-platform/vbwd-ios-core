import Foundation

/// Fetches available token bundles for purchase. Separate from `TokensViewModel`
/// (SRP) — this screen is the storefront, not the account balance/history view.
@MainActor
public final class BuyTokensViewModel: ObservableObject {
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var bundles: [TokenBundle] = []

    private let api: APIClient
    private let endpoints: StoreEndpoints

    public init(api: APIClient, endpoints: StoreEndpoints = StoreEndpoints()) {
        self.api = api
        self.endpoints = endpoints
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let r: TokenBundlesResponse? = try? await api.get(endpoints.tokenBundles)
        let list = r?.bundles ?? []
        bundles = list.sorted { ($0.sortOrder ?? Int.max) < ($1.sortOrder ?? Int.max) }
    }

    public func retry() async { await load() }
}
