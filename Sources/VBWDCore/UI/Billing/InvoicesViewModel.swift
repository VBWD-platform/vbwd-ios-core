import Foundation

/// Full invoice list with paginated loading (10 per page) and local search.
/// Loads the first page on `load()`, subsequent pages via `loadMoreIfNeeded(current:)`.
@MainActor
public final class InvoicesViewModel: ObservableObject {
    @Published public private(set) var isLoading = false
    @Published public private(set) var isLoadingMore = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var invoices: [Invoice] = []
    @Published public var searchText: String = ""

    /// Whether all pages have been fetched (no more to load).
    @Published public private(set) var allLoaded = false

    private let api: APIClient
    private let endpoints: DashboardEndpoints
    private let pageSize = 10
    private var currentOffset = 0

    public init(api: APIClient, endpoints: DashboardEndpoints = DashboardEndpoints()) {
        self.api = api
        self.endpoints = endpoints
    }

    /// Invoices filtered by the current search text (invoice number, amount,
    /// status, date — case-insensitive).
    public var filteredInvoices: [Invoice] {
        guard !searchText.isEmpty else { return invoices }
        let query = searchText.lowercased()
        return invoices.filter { inv in
            (inv.invoiceNumber ?? "").lowercased().contains(query)
            || (inv.amount ?? "").lowercased().contains(query)
            || (inv.totalAmount ?? "").lowercased().contains(query)
            || (inv.status ?? "").lowercased().contains(query)
            || (inv.invoicedAt ?? "").lowercased().contains(query)
            || inv.id.lowercased().contains(query)
        }
    }

    // MARK: - Initial load

    public func load() async {
        isLoading = true
        errorMessage = nil
        currentOffset = 0
        allLoaded = false

        let fetched = await fetchPage(offset: 0)
        invoices = fetched
        allLoaded = fetched.count < pageSize
        currentOffset = fetched.count
        isLoading = false
    }

    // MARK: - Pagination

    /// Call when the user scrolls near the last visible invoice.
    public func loadMoreIfNeeded(current: Invoice) async {
        // Only trigger when the current item is the last one
        guard let last = filteredInvoices.last, last.id == current.id else { return }
        guard !isLoadingMore && !allLoaded else { return }

        isLoadingMore = true
        let fetched = await fetchPage(offset: currentOffset)
        invoices.append(contentsOf: fetched)
        allLoaded = fetched.count < pageSize
        currentOffset += fetched.count
        isLoadingMore = false
    }

    public func retry() async { await load() }

    // MARK: - Private

    private func fetchPage(offset: Int) async -> [Invoice] {
        let base = endpoints.invoices
        let url = base + "?limit=\(pageSize)&offset=\(offset)"
        let r: InvoicesResponse? = try? await api.get(url)
        return r?.invoices ?? []
    }
}
