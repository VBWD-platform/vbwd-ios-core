import Foundation

/// Registry for menu items contributed by plugins. Port of navigation menu registry pattern.
/// Stores menu items by id and returns them sorted by order.
public final class MenuItemRegistry: @unchecked Sendable {
    private var items: [String: MenuItem] = [:]
    
    public init() {}
    
    public func add(_ item: MenuItem) {
        items[item.id] = item
    }
    
    public func remove(_ id: String) {
        items.removeValue(forKey: id)
    }
    
    public func all() -> [MenuItem] {
        items.values.sorted { $0.order < $1.order }
    }
    
    public func get(_ id: String) -> MenuItem? {
        items[id]
    }
}
