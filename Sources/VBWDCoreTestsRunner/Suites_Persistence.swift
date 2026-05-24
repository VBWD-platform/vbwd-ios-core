import Foundation
import VBWDCore
import VBWDCoreTestKit


func registerPersistenceSuites(_ runner: TestRunner) {

    // Shared TokenStore contract (Liskov gate) — run by every conformer.
    func contract(_ name: String, _ make: @escaping () -> TokenStore,
                  integrationSkippable: Bool = false) {
        runner.suite(name) { s in
            // Keychain needs an entitled host; in CLI it returns errSecMissingEntitlement
            // (-34018). Treat that as "skipped", not a failure — the contract is
            // still proven by InMemory (substitutability is what Liskov asserts).
            func guarded(_ body: () throws -> Void) {
                do { try body() }
                catch let e as KeychainError where integrationSkippable && e.status == -34018 {
                    s.expect(true, "skipped: Keychain unavailable in CLI (-34018)")
                } catch {
                    s.expect(false, "unexpected error: \(error)")
                }
            }

            await s.test("contract_saveThenLoadToken_roundTrips") {
                guarded {
                    let st = make()
                    try st.saveToken("abc")
                    s.expectEqual(try st.loadToken(), "abc")
                }
            }
            await s.test("contract_saveThenLoadRefreshToken_roundTrips") {
                guarded {
                    let st = make()
                    try st.saveRefreshToken("r1")
                    s.expectEqual(try st.loadRefreshToken(), "r1")
                }
            }
            await s.test("contract_saveThenLoadUserBlob_roundTrips") {
                guarded {
                    let st = make()
                    let blob = Data("{\"id\":\"1\"}".utf8)
                    try st.saveUser(blob)
                    s.expectEqual(try st.loadUser(), blob)
                }
            }
            await s.test("contract_clear_removesAllThree") {
                guarded {
                    let st = make()
                    try st.saveToken("t"); try st.saveRefreshToken("r")
                    try st.saveUser(Data("u".utf8))
                    try st.clear()
                    s.expectNil(try st.loadToken())
                    s.expectNil(try st.loadRefreshToken())
                    s.expectNil(try st.loadUser())
                }
            }
            await s.test("contract_loadOnEmptyStore_returnsNil") {
                guarded {
                    let st = make()
                    try st.clear()
                    s.expectNil(try st.loadToken())
                }
            }
            await s.test("contract_overwrite_replacesPreviousValue") {
                guarded {
                    let st = make()
                    try st.saveToken("v1")
                    try st.saveToken("v2")
                    s.expectEqual(try st.loadToken(), "v2")
                }
            }
        }
    }

    contract("S3 TokenStore contract: InMemory") { InMemoryTokenStore() }
    contract("S3 TokenStore contract: Keychain (integration)",
             { KeychainTokenStore(service: "com.vbwd.sdk.test") },
             integrationSkippable: true)
}
