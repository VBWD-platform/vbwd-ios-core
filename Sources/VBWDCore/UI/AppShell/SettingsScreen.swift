import SwiftUI

/// Settings screen with theme picker. Sprint 05: added Appearance section
/// with live theme switcher using ThemeManager from environment.
struct SettingsScreen: View {
    @Environment(\.isMenuOpen) var isMenuOpen
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.appTheme) var theme

    var body: some View {
        List {
            // Appearance — theme picker (Sprint 05)
            Section("Appearance") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(themeManager.currentTheme.id == themeManager.currentTheme.id
                            ? allThemes : allThemes, id: \.id) { t in
                        themeRow(t)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("theme_picker")
            }

            Section("Account") {
                Label("Notifications", systemImage: "bell")
                Label("Privacy", systemImage: "hand.raised")
            }
            Section("About") {
                Label("Version", systemImage: "info.circle")
            }
        }
        .accessibilityIdentifier("settings_view")
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .modifier(MenuToolbar())
    }

    private var allThemes: [any AppTheme] {
        [ClassicTheme(), DarkGreenTheme(), DarkBlueTheme()]
    }

    private func themeRow(_ t: any AppTheme) -> some View {
        Button(action: {
            themeManager.selectTheme(t.id)
        }) {
            HStack(spacing: 12) {
                // Color swatch
                Circle()
                    .fill(t.accent)
                    .frame(width: 24, height: 24)

                Text(t.displayName)
                    .foregroundColor(.primary)

                Spacer()

                if themeManager.currentTheme.id == t.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .accessibilityIdentifier("theme_selected_indicator")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("theme_option_\(t.id)")
    }
}
