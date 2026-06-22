import Foundation

/// In-memory, session-scoped cart. Port of the web `cart.ts` store from
/// `vbwd-fe-core`. Holds generic `CartItem`s that any plugin can add to
/// (token bundles, subscriptions, shop products). Unlike the web version,
/// the iOS cart is not localStorage-persisted — it lives for the session.
@MainActor
public final class Cart: ObservableObject {
    @Published public private(set) var items: [CartItem] = [] {
        didSet { notifyObservers() }
    }

    /// Incremented each time a view requests the cart checkout sheet to open.
    /// AppRoot observes this via `onChange` and presents the sheet.
    @Published public var checkoutRequestCount = 0

    /// Non-SwiftUI listeners (`MenuItem.badgeProvider` updaters, etc.) so
    /// plugins can mirror cart state into their own observables without
    /// pulling in Combine (S92). Always called on the main actor.
    private var observers: [([CartItem]) -> Void] = []

    /// Register a closure called on every cart mutation. The closure
    /// fires once immediately with the current items so callers don't
    /// need a separate priming step.
    public func observe(_ closure: @escaping ([CartItem]) -> Void) {
        observers.append(closure)
        closure(items)
    }

    private func notifyObservers() {
        for observer in observers { observer(items) }
    }

    /// Call to request opening the cart checkout sheet from any view.
    public func requestCheckout() {
        checkoutRequestCount += 1
    }

    public init() {}

    // MARK: - Mutations

    /// Add an item or increment quantity if an item with the same ID exists.
    public func add(_ item: CartItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].quantity += item.quantity
        } else {
            items.append(item)
        }
    }

    /// Remove an item by ID.
    public func remove(id: String) {
        items.removeAll { $0.id == id }
    }

    /// Set the quantity for an item. Removes the item if quantity <= 0.
    public func updateQuantity(id: String, quantity: Int) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        if quantity <= 0 {
            items.remove(at: idx)
        } else {
            items[idx].quantity = quantity
        }
    }

    /// Remove all items.
    public func clear() {
        items.removeAll()
    }

    // MARK: - Queries

    /// All items of a given type (e.g. `"token_bundle"`).
    public func items(ofType type: String) -> [CartItem] {
        items.filter { $0.type == type }
    }

    /// Sum of `price * quantity` for all items.
    public var total: Double {
        items.reduce(0) { $0 + $1.price * Double($1.quantity) }
    }

    public var isEmpty: Bool { items.isEmpty }

    public var itemCount: Int {
        items.reduce(0) { $0 + $1.quantity }
    }
}
