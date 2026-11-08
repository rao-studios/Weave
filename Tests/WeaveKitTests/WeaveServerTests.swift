//
//  WeaveServerTests.swift
//  WeaveKitTests
//
//  Weave's port, served for real on spare loopback ports, forwarding to a fake Thread that echoes
//  what it received: the body, the key, the path.
//

import Foundation
import Hummingbird
import Testing
@testable import WeaveKit

/// A fake AII Thread (and Sewn): answers every forwarded route with what it was sent.
private enum FakeThread {
    static func application(port: Int, ready: @escaping @Sendable () async -> Void) -> some ApplicationProtocol {
        let router = Router()
        for path in ["/v1/batch/embeddings", "/v1/library", "/v1/graph"] {
            router.post(RouterPath(path)) { request, context -> Response in try await echo(request, context, path) }
        }
        // A search echoes too, and answers its query as a found text, so `wait` sees it searchable.
        router.post("/v1/search") { request, context -> Response in try await echo(request, context, "/v1/search") }
        router.get("/v1/stats") { request, context -> Response in try await echo(request, context, "/v1/stats") }
        return Application(router: router, configuration: .init(address: .hostname("127.0.0.1", port: port)),
                           onServerRunning: { _ in await ready() }, logger: WeaveServer.quietLogger)
    }

    static func echo(_ request: Request, _ context: BasicRequestContext, _ path: String) async throws -> Response {
        var request = request
        let raw = try await request.collectBody(upTo: 1 << 20)
        let body = (try? JSONSerialization.jsonObject(with: Data(buffer: raw))) ?? NSNull()
        let key = request.headers.first { $0.name.canonicalName == "x-ambient-secret" }?.value ?? ""
        let query = ((body as? [String: Any])?["query"] as? String) ?? ""
        let answer: [String: Any] = ["path": path, "key": key, "received": body, "texts": [query], "references": [[String: Any]]()]
        return WeaveServer.respond(200, try JSONSerialization.data(withJSONObject: answer))
    }
}

private struct StubSource: WeaveGatewaySource {
    var threadPort: Int
    var hostUp: Bool
    func health() async -> WeaveHealth { WeaveHealth(status: "ok", app: "weave", port: 0, host: nil, threads: 2) }
    func threads() async -> WeaveThreads { WeaveThreads(host: nil, ownerId: WeaveIdentity.owner, threads: []) }
    func route(aii: String) async throws -> ForwardTarget {
        guard aii == "alpha" else { throw FabricError.notFound(aii) }
        return ForwardTarget(aii: aii, port: threadPort, secret: "alpha-key")
    }
    func host() async throws -> (target: ForwardTarget, names: [String: String]) {
        guard hostUp else { throw FabricError.noHost }
        return (ForwardTarget(aii: nil, port: threadPort, secret: "host-key"), ["t-1": "alpha"])
    }
    func secret() -> String? { "s3cret" }
    func served(_ path: String) async {}
}

@Suite(.serialized) struct WeaveServerTests {
    /// Runs the fake Thread on `fake` and Weave on `port` for the body, then stops both.
    private func serve(port: Int, fake: Int, hostUp: Bool = true, requireSecret: Bool = true,
                       _ body: @Sendable () async throws -> Void) async throws {
        let ready = AsyncStream<Void>.makeStream()
        let thread = FakeThread.application(port: fake) { ready.continuation.yield() }
        let weave = WeaveServer.application(port: port, source: StubSource(threadPort: fake, hostUp: hostUp), requireSecret: requireSecret) {
            ready.continuation.yield()
        }
        let tasks = [Task { try await thread.runService(gracefulShutdownSignals: []) },
                     Task { try await weave.runService(gracefulShutdownSignals: []) }]
        var count = 0
        for await _ in ready.stream { count += 1; if count == 2 { break } }
        defer { tasks.forEach { $0.cancel() } }
        try await body()
    }

    private func call(_ port: Int, _ path: String, method: String = "GET", body: String? = nil, secret: String? = "s3cret",
                      headers: [String: String] = [:]) async throws -> ([String: Any], Int) {
        var request = LoopbackHTTP.request(port: port, path: path, method: method, body: body.map { Data($0.utf8) }, secret: secret)
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        let (data, status) = try await LoopbackHTTP.send(request)
        return ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? ["raw": String(decoding: data, as: UTF8.self)], status)
    }

    @Test func healthIsOpenAndV1WantsTheSecret() async throws {
        try await serve(port: 47697, fake: 47687) {
            let status1 = try await call(47697, "/health", secret: nil).1
            #expect(status1 == 200)
            let status2 = try await call(47697, "/v1/threads", secret: nil).1
            #expect(status2 == 401)
            let status3 = try await call(47697, "/v1/threads", secret: "wrong").1
            #expect(status3 == 401)
            let (threads, ok) = try await call(47697, "/v1/threads")
            #expect(ok == 200 && (threads["forwards"] as? [String])?.contains("POST /v1/batch/embeddings") == true)
        }
    }

    @Test func aThreadInsertIsForwardedAsTheThreadTakesIt() async throws {
        try await serve(port: 47696, fake: 47686) {
            let body = #"{"weave": {"aii": "alpha", "wait": true}, "inputs": ["the loom"], "entities": [[{"name": "loom", "kind": "machine"}]], "thread": {"group": {"id": "g", "label": "G"}}}"#
            let (answer, status) = try await call(47696, "/v1/batch/embeddings", method: "POST", body: body)
            #expect(status == 200)
            #expect(answer["path"] as? String == "/v1/batch/embeddings" && answer["key"] as? String == "alpha-key", "the AII's own key")
            let received = try #require(answer["received"] as? [String: Any])
            #expect(received["weave"] == nil, "the routing spec is stripped")
            #expect((received["entities"] as? [[[String: Any]]])?.first?.first?["name"] as? String == "loom", "everything else passes untouched")
            let thread = try #require(received["thread"] as? [String: Any])
            #expect(thread["owner_id"] as? String == WeaveIdentity.owner)
            #expect((thread["group"] as? [String: Any])?["owner_id"] as? String == WeaveIdentity.owner)
            let weave = try #require(answer["weave"] as? [String: Any])
            #expect(weave["aii"] as? String == "alpha" && weave["indexed"] as? Bool == true)
        }
    }

    @Test func aCallersOwnOwnerPassesThroughWithANote() async throws {
        try await serve(port: 47695, fake: 47685) {
            let (answer, _) = try await call(47695, "/v1/search", method: "POST",
                                             body: #"{"query": "loom", "thread": {"owner_id": "me", "top_k": 3}}"#, headers: ["X-Weave-AII": "alpha"])
            let thread = try #require((answer["received"] as? [String: Any])?["thread"] as? [String: Any])
            #expect(thread["owner_id"] as? String == "me" && thread["scope"] as? String == "global")
            #expect(((answer["weave"] as? [String: Any])?["note"] as? String)?.contains("local-weave") == true)
        }
    }

    @Test func aSearchWithNoAIIGoesToTheHostAsSewnTakesIt() async throws {
        try await serve(port: 47694, fake: 47684) {
            let (answer, status) = try await call(47694, "/v1/search", method: "POST", body: #"{"query": "loom", "top_k": 4}"#)
            #expect(status == 200 && answer["key"] as? String == "host-key")
            let sewn = try #require((answer["received"] as? [String: Any])?["sewn"] as? [String: Any])
            #expect(sewn["owner_id"] as? String == WeaveIdentity.owner)
            #expect(((answer["weave"] as? [String: Any])?["threads"] as? [String: String]) == ["t-1": "alpha"])
        }
        try await serve(port: 47693, fake: 47683, hostUp: false) {
            let status4 = try await call(47693, "/v1/search", method: "POST", body: #"{"query": "loom"}"#).1
            #expect(status4 == 503)
        }
    }

    @Test func routingFailuresAreSaid() async throws {
        try await serve(port: 47692, fake: 47682) {
            let status5 = try await call(47692, "/v1/library", method: "POST", body: #"{"owner_id": "x"}"#).1
            #expect(status5 == 400, "no AII named")
            let status6 = try await call(47692, "/v1/library?aii=zeta", method: "POST", body: "{}").1
            #expect(status6 == 404, "an unknown AII")
            let status7 = try await call(47692, "/v1/library", method: "POST", body: "[1, 2]", headers: ["X-Weave-AII": "alpha"]).1
            #expect(status7 == 400, "not a JSON object")
            let (stats, ok) = try await call(47692, "/v1/stats?aii=alpha")
            #expect(ok == 200 && stats["path"] as? String == "/v1/stats")
        }
    }

    @Test func withoutTheGateTheSecretIsNotAsked() async throws {
        try await serve(port: 47691, fake: 47681, requireSecret: false) {
            let status8 = try await call(47691, "/v1/threads", secret: nil).1
            #expect(status8 == 200)
        }
    }
}
