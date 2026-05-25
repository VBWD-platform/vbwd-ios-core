import Foundation

/// View model for the invoice detail page. Fetches the full invoice
/// (with line items) from `GET /user/invoices/{id}` and supports
/// PDF download via `GET /user/invoices/{id}/pdf`.
@MainActor
public final class InvoiceDetailViewModel: ObservableObject {
    @Published public private(set) var isLoading = false
    @Published public private(set) var isDownloading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var invoice: Invoice?
    @Published public private(set) var pdfURL: URL?

    public let invoiceId: String
    private let api: APIClient

    public init(api: APIClient, invoiceId: String) {
        self.api = api
        self.invoiceId = invoiceId
    }

    public func load() async {
        isLoading = true
        errorMessage = nil

        let r: InvoiceDetailResponse? = try? await api.get("/user/invoices/\(invoiceId)")
        invoice = r?.invoice
        if invoice == nil {
            errorMessage = "Invoice not found."
        }
        isLoading = false
    }

    public func downloadPDF() async {
        isDownloading = true
        errorMessage = nil

        do {
            let data = try await api.getData("/user/invoices/\(invoiceId)/pdf")
            let filename = "invoice-\(invoice?.invoiceNumber ?? invoiceId).pdf"
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(filename)
            try data.write(to: fileURL)
            pdfURL = fileURL
        } catch {
            errorMessage = "Failed to download invoice PDF."
        }

        isDownloading = false
    }

    /// Clears the PDF URL after the share sheet is dismissed.
    public func clearPDF() {
        pdfURL = nil
    }
}
