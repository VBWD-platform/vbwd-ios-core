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

    /// Items assigned to a named section (e.g. `"top"`, `"store"`), sorted by order.
    public func items(inSection section: String) -> [MenuItem] {
        items.values.filter { $0.section == section }.sorted { $0.order < $1.order }
    }

    /// Items without a section assignment (rendered in the generic Plugin Items area).
    public func unsectionedItems() -> [MenuItem] {
        items.values.filter { $0.section == nil }.sorted { $0.order < $1.order }
    }
}
