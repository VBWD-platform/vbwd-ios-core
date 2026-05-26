import SwiftUI

/// Toolbar modifier that shows a back arrow alongside the hamburger menu
/// button. Used on detail pages (e.g. invoice detail) that need a quick
/// way to return to a parent list without opening the side menu.
struct BackButtonToolbar: ViewModifier {
    let backRoute: String

    @EnvironmentObject var host: PluginHost
    @Environment(\.isMenuOpen) var isMenuOpen
    @EnvironmentObject var cart: Cart

    func body(content: Content) -> some View {
        content
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        backButton
                        menuButton
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 12) {
                        backButton
                        menuButton
                    }
                }
                #endif
            }
    }

    private var backButton: some View {
        Button {
            host.selectedRoute = backRoute
        } label: {
            Image(systemName: "chevron.left")
                .font(.title3)
        }
        .accessibilityIdentifier("back_button")
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
