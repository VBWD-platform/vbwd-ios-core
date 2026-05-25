import Foundation
import VBWDCore
import VBWDCoreTestKit

func registerInvoiceDetailSuites(_ runner: TestRunner) {

    // MARK: S6d — InvoiceDetailViewModel

    runner.suite("S6d InvoiceDetailViewModel") { s in

        nonisolated(unsafe) let invoiceJSON = #"""
        {"invoice":{
          "id":"inv-42",
          "invoice_number":"INV-042",
          "invoiced_at":"2026-03-01T00:00:00Z",
          "amount":"100.00",
          "subtotal":"90.00",
          "tax_amount":"10.00",
          "total_amount":"100.00",
          "currency":"EUR",
          "status":"paid",
          "payment_method":"stripe",
          "payment_ref":"pi_abc123",
          "paid_at":"2026-03-02T10:00:00Z",
          "expires_at":"2026-04-01T00:00:00Z",
          "line_items":[
            {"id":"li-1","type":"token_bundle","description":"100 Tokens","quantity":1,"unit_price":"90.00","amount":"90.00"},
            {"id":"li-2","type":"tax","description":"VAT 10%","quantity":1,"unit_price":"10.00","amount":"10.00"}
          ]
        }}
        """#

        nonisolated(unsafe) let okRouter: SpyAPIClient.Router = { path, method, _ in
            if path == "/user/invoices/inv-42" && method == .get {
                return (200, Data(invoiceJSON.utf8))
            }
            if path == "/user/invoices/inv-42/pdf" && method == .get {
                return (200, Data("%PDF-1.4 fake".utf8))
            }
            return (404, Data())
        }

        await s.test("load_fetchesInvoice_withLineItems") { @MainActor in
            let spy = SpyAPIClient(router: okRouter)
            let vm = InvoiceDetailViewModel(api: spy, invoiceId: "inv-42")
            await vm.load()

            s.expect(!vm.isLoading)
            s.expectNil(vm.errorMessage)
            s.expectEqual(vm.invoice?.id, "inv-42")
            s.expectEqual(vm.invoice?.invoiceNumber, "INV-042")
            s.expectEqual(vm.invoice?.subtotal, "90.00")
            s.expectEqual(vm.invoice?.taxAmount, "10.00")
            s.expectEqual(vm.invoice?.totalAmount, "100.00")
            s.expectEqual(vm.invoice?.currency, "EUR")
            s.expectEqual(vm.invoice?.status, "paid")
            s.expectEqual(vm.invoice?.paymentRef, "pi_abc123")
            s.expectEqual(vm.invoice?.lineItems?.count, 2)
            s.expectEqual(vm.invoice?.lineItems?.first?.description, "100 Tokens")
        }

        await s.test("load_notFound_setsErrorMessage") { @MainActor in
            let router: SpyAPIClient.Router = { _, _, _ in (404, Data()) }
            let vm = InvoiceDetailViewModel(api: SpyAPIClient(router: router), invoiceId: "missing")
            await vm.load()

            s.expect(!vm.isLoading)
            s.expectEqual(vm.errorMessage, "Invoice not found.")
            s.expectNil(vm.invoice)
        }

        await s.test("load_serverError_setsErrorMessage") { @MainActor in
            let router: SpyAPIClient.Router = { _, _, _ in (500, Data()) }
            let vm = InvoiceDetailViewModel(api: SpyAPIClient(router: router), invoiceId: "inv-42")
            await vm.load()

            s.expect(!vm.isLoading)
            s.expectEqual(vm.errorMessage, "Invoice not found.")
            s.expectNil(vm.invoice)
        }

        await s.test("downloadPDF_writesToTempFile") { @MainActor in
            let spy = SpyAPIClient(router: okRouter)
            let vm = InvoiceDetailViewModel(api: spy, invoiceId: "inv-42")
            await vm.load()
            await vm.downloadPDF()

            s.expect(!vm.isDownloading)
            s.expectNil(vm.errorMessage)
            if let url = vm.pdfURL {
                s.expect(url.lastPathComponent.contains("invoice-"))
                s.expect(url.lastPathComponent.hasSuffix(".pdf"))
                // Verify data was actually written
                let data = try? Data(contentsOf: url)
                s.expect(data != nil)
                s.expect((data?.count ?? 0) > 0)
                // Clean up temp file
                try? FileManager.default.removeItem(at: url)
            } else {
                s.expect(false, "pdfURL should be set after download")
            }
        }

        await s.test("downloadPDF_failure_setsErrorMessage") { @MainActor in
            let router: SpyAPIClient.Router = { path, _, _ in
                if path == "/user/invoices/inv-42" {
                    return (200, Data(invoiceJSON.utf8))
                }
                return (500, Data())
            }
            let vm = InvoiceDetailViewModel(api: SpyAPIClient(router: router), invoiceId: "inv-42")
            await vm.load()
            await vm.downloadPDF()

            s.expect(!vm.isDownloading)
            s.expectEqual(vm.errorMessage, "Failed to download invoice PDF.")
            s.expectNil(vm.pdfURL)
        }

        await s.test("clearPDF_resetsURL") { @MainActor in
            let spy = SpyAPIClient(router: okRouter)
            let vm = InvoiceDetailViewModel(api: spy, invoiceId: "inv-42")
            await vm.load()
            await vm.downloadPDF()

            s.expect(vm.pdfURL != nil)
            vm.clearPDF()
            s.expectNil(vm.pdfURL)

            // Clean up if file exists
            if let url = vm.pdfURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        await s.test("isLoading_falseAfterLoad") { @MainActor in
            let vm = InvoiceDetailViewModel(api: SpyAPIClient(router: okRouter), invoiceId: "inv-42")
            s.expect(!vm.isLoading)
            await vm.load()
            s.expect(!vm.isLoading)
        }

        await s.test("invoiceId_storedCorrectly") { @MainActor in
            let vm = InvoiceDetailViewModel(
                api: SpyAPIClient(router: okRouter),
                invoiceId: "custom-id-123")
            s.expectEqual(vm.invoiceId, "custom-id-123")
        }

        await s.test("downloadPDF_callsCorrectEndpoint") { @MainActor in
            let spy = SpyAPIClient(router: okRouter)
            let vm = InvoiceDetailViewModel(api: spy, invoiceId: "inv-42")
            await vm.load()
            await vm.downloadPDF()

            let pdfCalls = spy.calls.filter { $0.path.contains("/pdf") }
            s.expectEqual(pdfCalls.count, 1)
            s.expectEqual(pdfCalls.first?.path, "/user/invoices/inv-42/pdf")
            s.expectEqual(pdfCalls.first?.method, .get)

            // Clean up temp file
            if let url = vm.pdfURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
