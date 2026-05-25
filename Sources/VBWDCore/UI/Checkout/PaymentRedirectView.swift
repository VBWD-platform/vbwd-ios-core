import SwiftUI

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

/// Displays a "Redirecting to payment…" message and opens the payment
/// provider's URL in `ASWebAuthenticationSession` (iOS) or the default browser
/// (macOS). On iOS the session auto-dismisses when the page redirects to the
/// `vbwd://` custom URL scheme, returning the callback URL (which contains the
/// Stripe `session_id`). Replaces the previous `SFSafariViewController`
/// approach which suffered from redirect loops and required manual dismissal.
struct PaymentRedirectView: View {
    let url: URL
    let callbackScheme: String
    let onComplete: (URL?) -> Void

    @Environment(\.appTheme) var theme
    #if os(iOS)
    // Retains the auth session so it isn't deallocated before completion.
    @StateObject private var sessionHolder = WebAuthSessionHolder()
    #endif

    init(url: URL,
         callbackScheme: String = "vbwd",
         onComplete: @escaping (URL?) -> Void) {
        self.url = url
        self.callbackScheme = callbackScheme
        self.onComplete = onComplete
    }

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
    }

    private func openPaymentURL() {
        #if os(iOS)
        startWebAuthSession()
        #else
        // macOS — open in default browser and proceed immediately
        NSWorkspace.shared.open(url)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            onComplete(nil)
        }
        #endif
    }

    #if os(iOS)
    private func startWebAuthSession() {
        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackScheme
        ) { [onComplete] callbackURL, error in
            DispatchQueue.main.async {
                if let callbackURL {
                    // Stripe redirected to vbwd://stripe-callback/success?session_id=cs_...
                    onComplete(callbackURL)
                } else {
                    // User cancelled or error
                    onComplete(nil)
                }
            }
        }
        session.prefersEphemeralWebBrowserSession = false
        session.presentationContextProvider = WebAuthPresentationContext.shared
        // Keep a strong reference so the session isn't deallocated.
        sessionHolder.session = session
        session.start()
    }
    #endif
}

// MARK: - Session Holder (iOS)

#if os(iOS)
/// Retains the `ASWebAuthenticationSession` for the lifetime of the view.
@MainActor
private final class WebAuthSessionHolder: ObservableObject {
    var session: ASWebAuthenticationSession?
}
#endif

// MARK: - Presentation Context (iOS)

#if os(iOS)
/// Provides the presentation anchor (key window) for ASWebAuthenticationSession.
private final class WebAuthPresentationContext: NSObject,
    ASWebAuthenticationPresentationContextProviding, @unchecked Sendable {

    @MainActor static let shared = WebAuthPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            return scene?.windows.first { $0.isKeyWindow }
                ?? UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
                    .first
                ?? ASPresentationAnchor()
        }
    }
}
#endif
