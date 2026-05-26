import SwiftUI

/// Full profile edit form. Port of `Profile.vue`: account info card (read-only),
/// personal info fields, address fields, change password section.
/// Thin view — all logic in `ProfileViewModel` (SRP).
struct ProfileEditView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let user: AuthUser
    @Environment(\.isMenuOpen) var isMenuOpen
    @EnvironmentObject var host: PluginHost

    /// ISO 3166-1 alpha-2 codes → display names. The backend stores country as
    /// the two-letter code (e.g. "DE"), so Picker tags must match.
    static let countries: [(code: String, name: String)] = [
        ("DE", "Germany"),  ("AT", "Austria"),  ("CH", "Switzerland"),
        ("US", "United States"), ("GB", "United Kingdom"), ("FR", "France"),
        ("NL", "Netherlands"), ("BE", "Belgium"), ("ES", "Spain"),
        ("IT", "Italy"),  ("PL", "Poland"),  ("CZ", "Czech Republic"),
        ("SE", "Sweden"), ("NO", "Norway"),  ("DK", "Denmark"),
        ("FI", "Finland"), ("CA", "Canada"), ("AU", "Australia"),
        ("JP", "Japan"),  ("ZZ", "Other"),
    ]

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading profile…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("profile_loading")
            } else {
                formContent
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile_edit_view")
        .navigationTitle("Profile")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .modifier(MenuToolbar())
        .task { await viewModel.load() }
    }

    private var formContent: some View {
        Form {
            // Error banner
            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .accessibilityIdentifier("profile_error_banner")
                }
            }

            // Success banner
            if let success = viewModel.successMessage {
                Section {
                    Text(success)
                        .foregroundColor(.green)
                        .accessibilityIdentifier("profile_success_banner")
                }
            }

            // Plugin-contributed Profile* sections (before core fields)
            let pluginSections = host.components.profileComponents()
            ForEach(pluginSections, id: \.name) { section in
                section.factory()
            }

            // Account info (read-only)
            Section("Account") {
                HStack {
                    Text("Email")
                    Spacer()
                    Text(user.email)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Status")
                    Spacer()
                    Text("Active")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            // Personal Information
            Section("Personal Information") {
                TextField("First Name", text: $viewModel.formData.firstName)
                    .accessibilityIdentifier("profile_first_name")
                TextField("Last Name", text: $viewModel.formData.lastName)
                    .accessibilityIdentifier("profile_last_name")
                TextField("Company", text: $viewModel.formData.company)
                    .accessibilityIdentifier("profile_company")
                TextField("Tax Number", text: $viewModel.formData.taxNumber)
                    .accessibilityIdentifier("profile_tax_number")
                TextField("Phone", text: $viewModel.formData.phone)
                    #if os(iOS)
                    .keyboardType(.phonePad)
                    #endif
                    .accessibilityIdentifier("profile_phone")
            }

            // Address
            Section("Address") {
                TextField("Address Line 1", text: $viewModel.formData.addressLine1)
                    .accessibilityIdentifier("profile_address_line_1")
                TextField("Address Line 2", text: $viewModel.formData.addressLine2)
                    .accessibilityIdentifier("profile_address_line_2")
                TextField("City", text: $viewModel.formData.city)
                    .accessibilityIdentifier("profile_city")
                TextField("Postal Code", text: $viewModel.formData.postalCode)
                    .accessibilityIdentifier("profile_postal_code")
                Picker("Country", selection: $viewModel.formData.country) {
                    Text("Select Country").tag("")
                    ForEach(Self.countries, id: \.code) { country in
                        Text(country.name).tag(country.code)
                    }
                }
                .accessibilityIdentifier("profile_country")
            }

            // Save button
            Section {
                Button(action: {
                    Task { await viewModel.save() }
                }) {
                    HStack {
                        Spacer()
                        Text(viewModel.isSaving ? "Saving…" : "Save Profile")
                        Spacer()
                    }
                }
                .disabled(viewModel.isSaving)
                .accessibilityIdentifier("profile_save_button")
            }

            // Change Password
            Section("Change Password") {
                SecureField("Current Password", text: $viewModel.passwordData.currentPassword)
                    #if os(iOS)
                    .textContentType(.password)
                    #endif
                    .accessibilityIdentifier("profile_current_password")
                SecureField("New Password", text: $viewModel.passwordData.newPassword)
                    #if os(iOS)
                    .textContentType(.newPassword)
                    #endif
                    .accessibilityIdentifier("profile_new_password")
                SecureField("Confirm Password", text: $viewModel.passwordData.confirmPassword)
                    #if os(iOS)
                    .textContentType(.newPassword)
                    #endif
                    .accessibilityIdentifier("profile_confirm_password")

                if let pwError = viewModel.passwordError {
                    Text(pwError)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .accessibilityIdentifier("profile_password_error")
                }

                if let pwSuccess = viewModel.passwordSuccess {
                    Text(pwSuccess)
                        .foregroundColor(.green)
                        .font(.footnote)
                }

                Button(action: {
                    Task { await viewModel.changePassword() }
                }) {
                    HStack {
                        Spacer()
                        Text("Change Password")
                        Spacer()
                    }
                }
                .accessibilityIdentifier("profile_change_password_button")
            }

        }
    }
}
