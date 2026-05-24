import Foundation

public typealias Unsubscribe = @Sendable () -> Void

public struct EventRecord: Equatable, Sendable {
    public let name: String
    public let at: Date
}

/// Pub/sub bus. Port of the web `EventBus` (`emit/on/once/off`, history,
/// backend batching with retry, local-only exclusion). Core ↔ plugin
/// communication goes through this only (OCP — neither imports the other).
public protocol EventBus: AnyObject, Sendable {
    func emit(_ name: String, _ payload: (any Sendable)?)
    @discardableResult
    func on(_ name: String, _ callback: @escaping @Sendable (any Sendable) -> Void) -> Unsubscribe
    func once(_ name: String, _ callback: @escaping @Sendable (any Sendable) -> Void)
    func off(_ name: String)
    func hasListeners(_ name: String) async -> Bool
    func listenerCount(_ name: String) async -> Int
    func history(_ name: String?) async -> [EventRecord]
    func clear()
    func clearHistory()
    /// Queue an event for the backend and flush the batch. Local-only events
    /// are excluded (returns false, not an error — web parity). Returns whether
    /// the batch reached the backend.
    @discardableResult
    func sendToBackend(_ name: String, _ payload: (any Encodable & Sendable)?) async -> Bool
    func flushPending() async -> Bool
    func pendingCount() async -> Int
}

public extension EventBus {
    func emit(_ name: String) { emit(name, nil) }
}

/// Default in-memory bus. Backend transport is the injected `APIClient`
/// (DIP — no `URLSession` here). `emit` never blocks on the network
/// (fire-and-forget, web behaviour). Uses an actor for async-safe state access.
public final class DefaultEventBus: EventBus {
    private struct Listener: Sendable { 
        let id: UUID
        let cb: @Sendable (any Sendable) -> Void 
    }
    private struct Pending: Encodable, Sendable { let name: String }

    private actor State {
        var listeners: [String: [Listener]] = [:]
        var records: [EventRecord] = []
        var pending: [Pending] = []
        let maxHistory: Int
        
        init(maxHistory: Int) {
            self.maxHistory = maxHistory
        }
        
        func record(_ name: String) {
            records.append(EventRecord(name: name, at: Date()))
            if records.count > maxHistory {
                records.removeFirst(records.count - maxHistory)
            }
        }
        
        func getListeners(_ name: String) -> [Listener] {
            listeners[name] ?? []
        }
        
        func addListener(_ name: String, _ listener: Listener) {
            listeners[name, default: []].append(listener)
        }
        
        func removeListener(_ name: String, id: UUID) {
            listeners[name]?.removeAll { $0.id == id }
        }
        
        func removeAllListeners(_ name: String) {
            listeners[name] = nil
        }
        
        func hasListeners(_ name: String) -> Bool {
            !(listeners[name]?.isEmpty ?? true)
        }
        
        func listenerCount(_ name: String) -> Int {
            listeners[name]?.count ?? 0
        }
        
        func getHistory(_ name: String?) -> [EventRecord] {
            guard let name else { return records }
            return records.filter { $0.name == name }
        }
        
        func clearAll() {
            listeners.removeAll()
            records.removeAll()
            pending.removeAll()
        }
        
        func clearHistory() {
            records.removeAll()
        }
        
        func addPending(_ item: Pending) {
            pending.append(item)
        }
        
        func getPendingBatch() -> [Pending] {
            pending
        }
        
        func removePending(count: Int) {
            pending.removeFirst(count)
        }
        
        func pendingCount() -> Int {
            pending.count
        }
    }

    private let state: State
    private let api: APIClient
    private let endpoint: String
    private let localOnly: Set<String>

    public init(api: APIClient,
                endpoint: String = "/events",
                maxHistory: Int = 100,
                localOnly: Set<String> = AppEvents.localOnly) {
        self.state = State(maxHistory: maxHistory)
        self.api = api
        self.endpoint = endpoint
        self.localOnly = localOnly
    }

    public nonisolated func emit(_ name: String, _ payload: (any Sendable)?) {
        Task {
            await state.record(name)
            let currentListeners = await state.getListeners(name)
            
            // Execute callbacks synchronously on the task
            currentListeners.forEach { $0.cb(payload ?? ()) }
        }
    }

    @discardableResult
    public nonisolated func on(_ name: String, _ callback: @escaping @Sendable (any Sendable) -> Void) -> Unsubscribe {
        let l = Listener(id: UUID(), cb: callback)
        let state = self.state
        
        Task {
            await state.addListener(name, l)
        }
        
        return { [state] in
            Task {
                await state.removeListener(name, id: l.id)
            }
        }
    }

    public nonisolated func once(_ name: String, _ callback: @escaping @Sendable (any Sendable) -> Void) {
        let unsubscribeBox = UnsubscribeBox()
        
        let unsub = on(name) { payload in
            callback(payload)
            unsubscribeBox.unsubscribe?()
        }
        
        unsubscribeBox.unsubscribe = unsub
    }

    public nonisolated func off(_ name: String) {
        Task {
            await state.removeAllListeners(name)
        }
    }

    public func hasListeners(_ name: String) async -> Bool {
        await state.hasListeners(name)
    }

    public func listenerCount(_ name: String) async -> Int {
        await state.listenerCount(name)
    }

    public func history(_ name: String?) async -> [EventRecord] {
        await state.getHistory(name)
    }

    public nonisolated func clear() {
        Task {
            await state.clearAll()
        }
    }
    
    public nonisolated func clearHistory() {
        Task {
            await state.clearHistory()
        }
    }
    
    public func pendingCount() async -> Int {
        await state.pendingCount()
    }

    @discardableResult
    public func sendToBackend(_ name: String, _ payload: (any Encodable & Sendable)?) async -> Bool {
        guard !localOnly.contains(name) else { return false }
        await state.addPending(Pending(name: name))
        return await flushPending()
    }

    public func flushPending() async -> Bool {
        let batch = await state.getPendingBatch()
        guard !batch.isEmpty else { return true }
        
        do {
            let _: EmptyResponse = try await api.post(endpoint, body: Batch(events: batch))
            await state.removePending(count: batch.count)
            return true
        } catch {
            return false   // keep pending; retried on next flush (web retry)
        }
    }

    private struct Batch: Encodable, Sendable { let events: [Pending] }
}

// Helper to work around capturing var in concurrent code
private final class UnsubscribeBox: @unchecked Sendable {
    var unsubscribe: Unsubscribe?
}
