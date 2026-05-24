import Foundation

/// A menu item that can be contributed by plugins. Port of web navigation menu items.
/// Plugins use this to add entries to the burger menu.
public struct MenuItem: Sendable, Identifiable {
    public let id: String
    public let icon: String  // SF Symbol name
    public let title: String
    public let badge: String?
    public let action: @Sendable () -> Void
    public let routePath: String?
    public let requiredPermission: String?
    public let order: Int
    
    public init(
        id: String,
        icon: String,
        title: String,
        badge: String? = nil,
        action: @escaping @Sendable () -> Void = {},
        routePath: String? = nil,
        requiredPermission: String? = nil,
        order: Int = 100
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.badge = badge
        self.action = action
        self.routePath = routePath
        self.requiredPermission = requiredPermission
        self.order = order
    }
}
