import SwiftUI

/// View that displays menu items contributed by plugins via the SDK.
/// Reads from the PluginHost's SDK menuItems registry and renders them using MenuItemButton.
public struct PluginMenuItems: View {
    let onClose: () -> Void
    @EnvironmentObject var host: PluginHost
    
    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    public var body: some View {
        let items = host.sdk.getMenuItems()
        
        ForEach(items) { item in
            MenuItemButton(
                icon: item.icon,
                title: item.title,
                badge: item.badge,
                action: {
                    if let routePath = item.routePath {
                        host.selectedRoute = routePath
                    }
                    item.action()
                    onClose()
                }
            )
        }
    }
}
