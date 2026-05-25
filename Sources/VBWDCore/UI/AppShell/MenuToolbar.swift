import SwiftUI

/// Adds the hamburger menu button to the navigation bar leading position.
/// Used by non-dashboard screens that still need menu access.
struct MenuToolbar: ViewModifier {
    @Environment(\.isMenuOpen) var isMenuOpen

    func body(content: Content) -> some View {
        content
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    menuButton
                }
                #else
                ToolbarItem(placement: .automatic) {
                    menuButton
                }
                #endif
            }
    }

    private var menuButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                isMenuOpen.wrappedValue.toggle()
            }
        }) {
            Image(systemName: "line.3.horizontal")
                .font(.title3)
        }
        .accessibilityIdentifier("menu_button")
    }
}
