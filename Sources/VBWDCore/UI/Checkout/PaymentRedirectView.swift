import SwiftUI

#if canImport(SafariServices)
import SafariServices
#endif

/// Displays a "Redirecting to payment…" message and opens the payment
/// provider's URL in `SFSafariViewController` (iOS) or the default browser
/// (macOS). When the user returns (dismiss / completion), calls `onComplete`.
/// Mirrors the web `StripePaymentView.vue` redirect flow.
struct PaymentRedirectView: View {
    let url: URL
    let onComplete: () -> Void

    @Environment(\.appTheme) var theme
    @State private var showingSafari = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .padding(.bottom, 8)

            Text("Redirecting to payment\u{2026}")
                .font(.title3)
                .foregroundColor(theme.textPrimary)

            Text("Complete your payment in the browser. You will be returned here when finished.")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("payment_redirect_view")
        .onAppear { openPaymentURL() }
        #if os(iOS)
        .sheet(isPresented: $showingSafari) {
            onComplete()
        } content: {
            SafariView(url: url)
                .ignoresSafeArea()
        }
        #endif
    }

    private func openPaymentURL() {
        #if os(iOS)
        showingSafari = true
        #else
        // macOS — open in default browser and proceed immediately
        NSWorkspace.shared.open(url)
        // Give user a moment to see the browser opened, then move to confirmation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            onComplete()
        }
        #endif
    }
}

// MARK: - Safari View (iOS)

#if os(iOS)
/// UIKit wrapper for `SFSafariViewController`.
private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = .systemBlue
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
#endif
