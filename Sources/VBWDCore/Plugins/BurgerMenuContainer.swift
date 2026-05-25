import SwiftUI

/// Container view that provides a slide-in burger menu (hamburger menu).
/// Wraps the main content and overlays the menu when opened.
public struct BurgerMenuContainer<Content: View>: View {
    @State private var isMenuOpen = false
    let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        ZStack(alignment: .leading) {
            // Main content
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    // Dim overlay when menu open — only present in hierarchy
                    // when menu is open, so it doesn't block XCTest hittability.
                    Group {
                        if isMenuOpen {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isMenuOpen = false
                                    }
                                }
                        }
                    }
                )
            
            // Side menu
            if isMenuOpen {
                SideMenu(onClose: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isMenuOpen = false
                    }
                })
                .frame(width: 280)
                .transition(.move(edge: .leading))
            }
        }
        .environment(\.isMenuOpen, $isMenuOpen)
    }
}

// Environment key for menu state
private struct MenuOpenKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

// Environment key for cart checkout sheet
private struct ShowCartCheckoutKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var isMenuOpen: Binding<Bool> {
        get { self[MenuOpenKey.self] }
        set { self[MenuOpenKey.self] = newValue }
    }

    public var showCartCheckout: Binding<Bool> {
        get { self[ShowCartCheckoutKey.self] }
        set { self[ShowCartCheckoutKey.self] = newValue }
    }
}
