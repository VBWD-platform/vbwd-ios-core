import SwiftUI

/// Adds the hamburger menu button to the navigation bar leading position.
/// Used by non-dashboard screens that still need menu access.
/// Shows a red badge dot when the cart has items.
struct MenuToolbar: ViewModifier {
    @Environment(\.isMenuOpen) var isMenuOpen
    @EnvironmentObject var cart: Cart

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
                .overlay(alignment: .topTrailing) {
                    if !cart.isEmpty {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 4, y: -4)
                    }
                }
        }
        .accessibilityIdentifier("menu_button")
    }
}
