/// Dashboard data models + endpoints. Shapes mirror the fields the backend
/// `invoice.to_dict()` returns (web `Invoices.vue` / `InvoiceDetail.vue`).
public struct Invoice: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let invoiceNumber: String?
    public let invoicedAt: String?
    public let amount: String?
    public let subtotal: String?
    public let taxAmount: String?
    public let totalAmount: String?
    public let currency: String?
    public let status: String?
    public let paymentMethod: String?
    public let paymentRef: String?
    public let paidAt: String?
    public let expiresAt: String?
    public let lineItems: [InvoiceLineItem]?

    enum CodingKeys: String, CodingKey {
        case id, amount, subtotal, currency, status
        case invoiceNumber = "invoice_number"
        case invoicedAt = "invoiced_at"
        case taxAmount = "tax_amount"
        case totalAmount = "total_amount"
        case paymentMethod = "payment_method"
        case paymentRef = "payment_ref"
        case paidAt = "paid_at"
        case expiresAt = "expires_at"
        case lineItems = "line_items"
    }
}

/// Line item within an invoice. Returned by the detail endpoint
/// `GET /user/invoices/{id}`.
public struct InvoiceLineItem: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let type: String?
    public let description: String?
    public let quantity: Int?
    public let unitPrice: String?
    public let amount: String?

    enum CodingKeys: String, CodingKey {
        case id, type, description, quantity, amount
        case unitPrice = "unit_price"
    }
}

public struct TokenTransaction: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let amount: Double
    public let transactionType: String?
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, amount
        case transactionType = "transaction_type"
        case createdAt = "created_at"
    }
}

struct TokenBalanceResponse: Codable { let balance: Double? }
struct TokenTransactionsResponse: Codable { let transactions: [TokenTransaction]? }
struct InvoicesResponse: Codable { let invoices: [Invoice]? }
struct InvoiceDetailResponse: Codable { let invoice: Invoice? }

/// Configurable dashboard endpoints (web `Dashboard.vue` paths).
public struct DashboardEndpoints: Equatable, Sendable {
    public var tokenBalance: String
    public var tokenTransactions: String
    public var invoices: String

    public init(tokenBalance: String = "/user/tokens/balance",
                tokenTransactions: String = "/user/tokens/transactions?limit=10",
                invoices: String = "/user/invoices") {
        self.tokenBalance = tokenBalance
        self.tokenTransactions = tokenTransactions
        self.invoices = invoices
    }
}
