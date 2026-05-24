import Foundation
import VBWDCore
import VBWDCoreTestKit

private let baseURL = URL(string: "https://example.test")!


func registerNetworkingSuites(_ runner: TestRunner) {

    // MARK: S1 — APIClientConfig
    runner.suite("S1 APIClientConfig") { s in
        await s.test("defaultTimeout_is30Seconds") {
            s.expectEqual(APIClientConfig.defaultTimeout, 30)
            s.expectEqual(APIClientConfig(baseURL: baseURL).timeout, 30)
        }
        await s.test("baseURL_isStoredVerbatim") {
            s.expectEqual(APIClientConfig(baseURL: baseURL).baseURL, baseURL)
        }
        await s.test("defaultHeaders_includeJSONContentType") {
            s.expectEqual(APIClientConfig(baseURL: baseURL).headers["Content-Type"],
                          "application/json")
        }
        await s.test("customHeaders_mergeOverDefaults") {
            let c = APIClientConfig(baseURL: baseURL,
                                    headers: ["Content-Type": "text/plain",
                                              "X-App": "ios"])
            s.expectEqual(c.headers["Content-Type"], "text/plain")
            s.expectEqual(c.headers["X-App"], "ios")
        }
    }

    // MARK: S1 — APIError
    runner.suite("S1 APIError") { s in
        await s.test("http400_mapsToHTTPCase_withStatusAndBody") {
            let e = APIError.fromResponse(status: 400,
                                          body: Data("{\"error\":\"bad\"}".utf8),
                                          statusText: "Bad Request")
            s.expectEqual(e, .http(status: 400, message: "bad"))
        }
        await s.test("http500_mapsToHTTPCase") {
            let e = APIError.fromResponse(status: 500, body: Data(),
                                          statusText: "Server Error")
            s.expectEqual(e, .http(status: 500, message: "Server Error"))
        }
        await s.test("transportFailure_mapsToTransportCase") {
            let e = APIError.fromTransport(URLError(.notConnectedToInternet))
            if case .transport = e { s.expect(true) } else { s.expect(false, "not .transport") }
        }
        await s.test("decodingFailure_mapsToDecodingCase") {
            struct X: Decodable { let a: Int }
            do { _ = try JSONDecoder().decode(X.self, from: Data("{}".utf8)); s.expect(false) }
            catch {
                if case .decoding = APIError.fromDecoding(error) { s.expect(true) }
                else { s.expect(false, "not .decoding") }
            }
        }
        await s.test("message_prefersErrorKey_thenMessageKey_thenStatusText") {
            s.expectEqual(APIError.fromResponse(status: 400,
                body: Data("{\"error\":\"E\",\"message\":\"M\"}".utf8),
                statusText: "S").message, "E")
            s.expectEqual(APIError.fromResponse(status: 400,
                body: Data("{\"message\":\"M\"}".utf8),
                statusText: "S").message, "M")
            s.expectEqual(APIError.fromResponse(status: 400,
                body: Data("{}".utf8), statusText: "S").message, "S")
        }
    }

    // MARK: S2 — URLSessionAPIClient
    runner.suite("S2 URLSessionAPIClient") { s in
        struct Echo: Codable, Equatable { let value: String }

        func makeClient(token: String? = nil) -> URLSessionAPIClient {
            URLSessionAPIClient(config: APIClientConfig(baseURL: baseURL),
                                session: StubURLProtocol.session(),
                                tokenProvider: MutableTokenProvider(token: token))
        }

        await s.test("get_decodesResponseBodyIntoType") {
            StubURLProtocol.handler = { _ in
                (200, try! JSONEncoder().encode(Echo(value: "hi")))
            }
            let c = makeClient()
            let r: Echo = try await c.get("/thing")
            s.expectEqual(r, Echo(value: "hi"))
        }

        await s.test("post_sendsJSONEncodedBody_andContentTypeApplicationJSON") {
            StubURLProtocol.handler = { req in
                let body = StubURLProtocol.bodyData(req) ?? Data()
                return (200, body)
            }
            let c = makeClient()
            let sent = Echo(value: "x")
            let r: Echo = try await c.post("/echo", body: sent)
            s.expectEqual(r, sent)
            s.expectEqual(
                StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type"),
                "application/json")
        }

        await s.test("bearerHeader_added_whenTokenProviderYieldsToken") {
            StubURLProtocol.handler = { _ in (200, try! JSONEncoder().encode(Echo(value: "a"))) }
            let c = makeClient(token: "TKN")
            let _: Echo = try await c.get("/thing")
            s.expectEqual(
                StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"),
                "Bearer TKN")
        }

        await s.test("bearerHeader_absent_whenTokenProviderEmpty") {
            StubURLProtocol.handler = { _ in (200, try! JSONEncoder().encode(Echo(value: "a"))) }
            let c = makeClient(token: nil)
            let _: Echo = try await c.get("/thing")
            s.expectNil(
                StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"))
        }

        await s.test("non2xx_throwsMappedAPIError_withBody") {
            StubURLProtocol.handler = { _ in (422, Data("{\"error\":\"nope\"}".utf8)) }
            let c = makeClient()
            do {
                let _: Echo = try await c.get("/thing")
                s.expect(false, "should have thrown")
            } catch {
                s.expectEqual(error as? APIError, .http(status: 422, message: "nope"))
            }
        }

        await s.test("status401_emitsTokenExpiredEvent_exactlyOnce") {
            StubURLProtocol.handler = { _ in (401, Data("{\"error\":\"x\"}".utf8)) }
            let c = makeClient()
            nonisolated(unsafe) var count = 0
            c.on(.tokenExpired) { count += 1 }
            // Yield to let fire-and-forget on() Task register the handler
            try? await Task.sleep(nanoseconds: 50_000_000)
            do { let _: Echo = try await c.get("/thing") } catch {}
            // Yield to let fire-and-forget emit() Task invoke handler
            try? await Task.sleep(nanoseconds: 50_000_000)
            s.expectEqual(count, 1)
        }

        await s.test("get_put_patch_delete_useCorrectHTTPMethods") {
            nonisolated(unsafe) var seen: [String] = []
            StubURLProtocol.handler = { req in
                seen.append(req.httpMethod ?? "?")
                return (200, try! JSONEncoder().encode(Echo(value: "m")))
            }
            let c = makeClient()
            let _: Echo = try await c.get("/thing")
            let _: Echo = try await c.put("/thing", body: Echo(value: "p"))
            let _: Echo = try await c.patch("/thing", body: Echo(value: "p"))
            let _: Echo = try await c.delete("/thing")
            s.expectEqual(seen, ["GET", "PUT", "PATCH", "DELETE"])
        }
    }

    // MARK: S2 — Liskov contract (both conformers)
    func contractSuite(_ name: String, _ make: @escaping () -> APIClient) {
        runner.suite(name) { s in
            await s.test("contract_getReturnsDecodedValue") {
                let r: Contract.Echo = try await make().get("/thing")
                s.expectEqual(r, Contract.Echo(value: "hello"))
            }
            await s.test("contract_postEchoesSentBody") {
                let sent = Contract.Echo(value: "abc")
                let r: Contract.Echo = try await make().post("/echo", body: sent)
                s.expectEqual(r, sent)
            }
            await s.test("contract_errorResponseThrowsAPIError") {
                do {
                    let _: Contract.Echo = try await make().get("/boom")
                    s.expect(false, "should have thrown")
                } catch {
                    s.expectEqual(error as? APIError, .http(status: 500, message: "boom"))
                }
            }
        }
    }

    contractSuite("S2 Contract: SpyAPIClient") {
        SpyAPIClient(router: Contract.route)
    }
    contractSuite("S2 Contract: URLSessionAPIClient") {
        StubURLProtocol.handler = { req in
            let m = HTTPMethod(rawValue: req.httpMethod ?? "GET") ?? .get
            return Contract.route(req.url!.path, m, StubURLProtocol.bodyData(req))
        }
        return URLSessionAPIClient(config: APIClientConfig(baseURL: baseURL),
                                   session: StubURLProtocol.session())
    }
}
