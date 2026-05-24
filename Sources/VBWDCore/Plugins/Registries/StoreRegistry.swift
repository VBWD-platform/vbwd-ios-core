/// Registry of plugin stores. Port of Pinia `createStore`/`getStores`: a
/// plugin registers an `AnyObject` (typically an `ObservableObject`) by id;
/// duplicate ids are rejected.
public final class StoreRegistry {
    private var stores: [String: AnyObject] = [:]

    public init() {}

    public func create(_ id: String, _ store: AnyObject) throws {
        guard stores[id] == nil else { throw RegistryError.duplicateStoreId(id) }
        stores[id] = store
    }

    public func get(_ id: String) -> AnyObject? { stores[id] }

    public func all() -> [String: AnyObject] { stores }
}
