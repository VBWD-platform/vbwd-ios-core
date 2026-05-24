import SwiftUI

/// Thin login form. Port of `Login.vue`. All logic lives in `LoginViewModel`.
/// Sprint 05: uses theme colors.
public struct LoginView: View {
    @ObservedObject private var viewModel: LoginViewModel
    @Environment(\.appTheme) var theme

    public init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 20) {
            Text("Sign in").font(.title).bold()
                .foregroundColor(theme.textPrimary)

            TextField("Email", text: $viewModel.email)
                #if os(iOS)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                #endif
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("login_email_field")

            SecureField("Password", text: $viewModel.password)
                #if os(iOS)
                .textContentType(.password)
                #endif
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("login_password_field")

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(theme.destructive)
                    .font(.footnote)
                    .accessibilityIdentifier("login_error_label")
            }

            Button {
                Task { await viewModel.submit() }
            } label: {
                Text(viewModel.isLoading ? "Signing in…" : "Sign in")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSubmit)
            .accessibilityIdentifier("login_submit_button")
        }
        .padding(32)
        .frame(maxWidth: 400)
    }
}
