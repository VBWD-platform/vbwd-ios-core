import Foundation
import VBWDCore
import VBWDCoreTestKit

func registerEventBusSuites(_ runner: TestRunner) {

    func bus(_ router: @escaping SpyAPIClient.Router = { _, _, _ in (200, Data()) })
        -> (DefaultEventBus, SpyAPIClient) {
        let api = SpyAPIClient(router: router)
        return (DefaultEventBus(api: api), api)
    }

    /// Yield to let fire-and-forget Tasks in EventBus complete.
    func yieldForTasks() async {
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }

    // MARK: P6 — pub/sub
    runner.suite("P6 EventBus pub/sub") { s in
        await s.test("emit_then_listener_receivesPayload") {
            let (b, _) = bus()
            nonisolated(unsafe) var got: Int?
            b.on("e") { got = $0 as? Int }
            await yieldForTasks()
            b.emit("e", 42)
            await yieldForTasks()
            s.expectEqual(got, 42)
        }
        await s.test("on_returnsUnsubscribe_thatStopsDelivery") {
            let (b, _) = bus()
            nonisolated(unsafe) var n = 0
            let unsub = b.on("e") { _ in n += 1 }
            await yieldForTasks()
            b.emit("e", nil)
            await yieldForTasks()
            unsub()
            await yieldForTasks()
            b.emit("e", nil)
            await yieldForTasks()
            s.expectEqual(n, 1)
        }
        await s.test("once_firesExactlyOnce") {
            let (b, _) = bus()
            nonisolated(unsafe) var n = 0
            b.once("e") { _ in n += 1 }
            await yieldForTasks()
            b.emit("e", nil)
            await yieldForTasks()
            b.emit("e", nil)
            await yieldForTasks()
            s.expectEqual(n, 1)
        }
        await s.test("off_removesAllListenersForEvent") {
            let (b, _) = bus()
            nonisolated(unsafe) var n = 0
            b.on("e") { _ in n += 1 }; b.on("e") { _ in n += 1 }
            await yieldForTasks()
            b.off("e")
            await yieldForTasks()
            b.emit("e", nil)
            await yieldForTasks()
            s.expectEqual(n, 0)
            let hasAfterOff = await b.hasListeners("e")
            s.expect(!hasAfterOff)
        }
        await s.test("hasListeners_listenerCount_accurate") {
            let (b, _) = bus()
            let count0 = await b.listenerCount("e")
            s.expectEqual(count0, 0)
            b.on("e") { _ in }; b.on("e") { _ in }
            await yieldForTasks()
            let count2 = await b.listenerCount("e")
            s.expectEqual(count2, 2)
            let hasE = await b.hasListeners("e")
            s.expect(hasE)
        }
        await s.test("multiple_listeners_allInvoked_inRegistrationOrder") {
            let (b, _) = bus()
            nonisolated(unsafe) var order: [Int] = []
            b.on("e") { _ in order.append(1) }
            b.on("e") { _ in order.append(2) }
            await yieldForTasks()
            b.emit("e", nil)
            await yieldForTasks()
            s.expectEqual(order, [1, 2])
        }
        await s.test("history_capped_at_max_and_filteredByEvent") {
            let api = SpyAPIClient()
            let b = DefaultEventBus(api: api, maxHistory: 3)
            for _ in 0..<5 { b.emit("a", nil) }
            b.emit("b", nil)
            await yieldForTasks()
            s.expectEqual(await b.history(nil).count, 3)            // capped
            s.expectEqual(await b.history("b").count, 1)            // filtered
        }
        await s.test("clear_removesListenersAndHistory") {
            let (b, _) = bus()
            b.on("e") { _ in }
            await yieldForTasks()
            b.emit("e", nil)
            await yieldForTasks()
            b.clear()
            await yieldForTasks()
            let hasClear = await b.hasListeners("e")
            s.expect(!hasClear)
            s.expectEqual(await b.history(nil).count, 0)
        }
    }

    // MARK: P6 — backend batching
    runner.suite("P6 EventBus backend") { s in
        await s.test("sendToBackend_postsBatch_toEventsEndpoint") {
            nonisolated(unsafe) var hitPath: String?
            let (b, _) = bus { path, method, _ in
                if path == "/events", method == .post { hitPath = path; return (200, Data()) }
                return (404, Data())
            }
            let ok = await b.sendToBackend("user:registered", nil)
            s.expect(ok)
            s.expectEqual(hitPath, "/events")
            s.expectEqual(await b.pendingCount(), 0)
        }
        await s.test("localOnly_events_excludedFromBackend") {
            nonisolated(unsafe) var posted = false
            let (b, _) = bus { _, _, _ in posted = true; return (200, Data()) }
            let ok = await b.sendToBackend(AppEvents.loadingStart, nil)
            s.expect(!ok)           // excluded → not sent (not an error)
            s.expect(!posted)
            s.expectEqual(await b.pendingCount(), 0)
        }
        await s.test("failedBatch_isRetried_thenPendingReflectsIt") {
            nonisolated(unsafe) var fail = true
            let (b, _) = bus { _, _, _ in fail ? (500, Data()) : (200, Data()) }
            let first = await b.sendToBackend("payment:succeeded", nil)
            s.expect(!first)
            s.expectEqual(await b.pendingCount(), 1)   // kept for retry
            fail = false
            let retried = await b.flushPending()
            s.expect(retried)
            s.expectEqual(await b.pendingCount(), 0)
        }
        await s.test("emit_doesNotThrow_norBlock_onBackendFailure") {
            let (b, _) = bus { _, _, _ in (500, Data()) }
            b.emit("anything", nil)              // fire-and-forget, no throw
            s.expect(true)
        }
    }

    // MARK: P6 — AppEvents catalog + Liskov transport contract
    runner.suite("P6 AppEvents & transport contract") { s in
        await s.test("catalog_matches_web") {
            s.expectEqual(AppEvents.authLogin, "auth:login")
            s.expectEqual(AppEvents.pluginInitialized, "plugin:initialized")
            s.expectEqual(AppEvents.paymentSucceeded, "payment:succeeded")
            s.expect(AppEvents.localOnly.contains("modal:open"))
            s.expect(!AppEvents.localOnly.contains("auth:login"))
        }
        // EventTransportContract: identical batching behaviour regardless of
        // which APIClient conformer backs it (Liskov via Sprint-01 contract).
        await s.test("transportContract_spyClient_batchesAndClears") {
            let (b, _) = bus { p, _, _ in p == "/events" ? (200, Data()) : (404, Data()) }
            _ = await b.sendToBackend("user:updated", nil)
            s.expectEqual(await b.pendingCount(), 0)
        }
        await s.test("transportContract_failingClient_keepsPending") {
            let (b, _) = bus { _, _, _ in (503, Data()) }
            _ = await b.sendToBackend("user:updated", nil)
            s.expectEqual(await b.pendingCount(), 1)
        }
    }
}
