import Foundation

/// Full invoice list. Dedicated screen counterpart of the dashboard's
/// "Recent invoices" card. Pattern mirrors `DashboardViewModel`: silent
/// failure (empty list shown on error).
@MainActor
public final class InvoicesViewModel: ObservableObject {
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var invoices: [Invoice] = []

    private let api: APIClient
    private let endpoints: DashboardEndpoints

    public init(api: APIClient, endpoints: DashboardEndpoints = DashboardEndpoints()) {
        self.api = api
        self.endpoints = endpoints
    }

    public func load() async {
        isLoading = true
        errorMessage = nil

        let r: InvoicesResponse? = try? await api.get(endpoints.invoices)
        invoices = r?.invoices ?? []
        isLoading = false
    }

    public func retry() async { await load() }
}
