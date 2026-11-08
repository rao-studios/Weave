//
//  WeaveServerTests.swift
//  WeaveKitTests
//
//  Weave's port, served for real on a spare loopback port and asked through Weave's own client.
//

import Foundation
import Hummingbird
import Testing
@testable import WeaveKit

private struct StubSource: WeaveGatewaySource {
    var hostUp: Bool
    func health() async -> WeaveHealth { WeaveHealth(status: "ok", app: "weave", port: 0, host: nil, threads: 2) }
    func threads() async -> WeaveThreads { WeaveThreads(host: nil, ownerId: WeaveIdentity.owner, threads: []) }
    func search(_ request: WeaveSearchRequest) async throws -> WeaveSearchResponse {
        guard hostUp else { throw FabricError.noHost }
        return WeaveSearchResponse(host: nil, texts: ["echo \(request.query)"], references: [], hits: [], graph: nil)
    }
    func push(_ request: WeavePushRequest, thread: String) async throws -> WeavePushResponse {
        guard thread == "alpha" else { throw FabricError.notFound(thread) }
        return WeavePushResponse(thread: thread, ownerId: WeaveIdentity.owner, group: ThreadGateway.group(thread: thread, label: request.group),
                                 filed: request.all.count, indexed: true, documents: request.all.count)
    }
    func search(_ request: WeaveThreadSearchRequest, thread: String) async throws -> WeaveThreadSearchResponse {
        guard thread == "alpha" else { throw FabricError.notFound(thread) }
        return WeaveThreadSearchResponse(thread: thread, hits: [WeaveThreadHit(rank: 1, text: "alpha says \(request.query)", documentId: "d", partitionId: "p")])
    }
    func records(thread: String) async throws -> WeaveRecordsResponse {
        WeaveRecordsResponse(thread: thread, ownerId: WeaveIdentity.owner, groups: [])
    }
    func secret() -> String? { "s3cret" }
    func served(_ path: String) async {}
}

@Suite(.serialized) struct WeaveServerTests {
    /// Runs the server on `port` for the body, then stops it.
    private func serve(_ source: StubSource, port: Int, requireSecret: Bool = true,
                       _ body: @Sendable () async throws -> Void) async throws {
        let ready = AsyncStream<Void>.makeStream()
        let app = WeaveServer.application(port: port, source: source, requireSecret: requireSecret) { ready.continuation.yield() }
        let task = Task { try await app.runService(gracefulShutdownSignals: []) }
        for await _ in ready.stream { break }
        defer { task.cancel() }
        try await body()
    }

    private func call(_ port: Int, _ path: String, method: String = "GET", body: String? = nil, secret: String? = nil) async throws -> (String, Int) {
        let (data, status) = try await LoopbackHTTP.send(LoopbackHTTP.request(port: port, path: path, method: method,
                                                                              body: body.map { Data($0.utf8) }, secret: secret))
        return (String(decoding: data, as: UTF8.self), status)
    }

    @Test func healthIsOpenAndV1WantsTheSecret() async throws {
        try await serve(StubSource(hostUp: true), port: 47697) {
            let (health, ok) = try await call(47697, "/health")
            #expect(ok == 200 && health.contains("\"threads\":2"))
            let bare = try await call(47697, "/v1/threads").1
            let wrong = try await call(47697, "/v1/threads", secret: "wrong").1
            #expect(bare == 401 && wrong == 401)
            let (threads, allowed) = try await call(47697, "/v1/threads", secret: "s3cret")
            #expect(allowed == 200 && threads.contains("local-weave"))
        }
    }

    @Test func searchForwardsAndSaysWhenNoHostIsUp() async throws {
        try await serve(StubSource(hostUp: true), port: 47696) {
            let (answer, status) = try await call(47696, "/v1/search", method: "POST", body: #"{"query":"loom"}"#, secret: "s3cret")
            #expect(status == 200 && answer.contains("echo loom"))
            let empty = try await call(47696, "/v1/search", method: "POST", body: #"{"query":"  "}"#, secret: "s3cret").1
            #expect(empty == 400)
        }
        try await serve(StubSource(hostUp: false), port: 47695) {
            let status = try await call(47695, "/v1/search", method: "POST", body: #"{"query":"loom"}"#, secret: "s3cret").1
            #expect(status == 503)
        }
    }

    @Test func withoutTheGateTheSecretIsNotAsked() async throws {
        try await serve(StubSource(hostUp: true), port: 47694, requireSecret: false) {
            let status = try await call(47694, "/v1/threads").1
            #expect(status == 200)
        }
    }

    @Test func anInsertNamesItsAIIInTheBodyAndASearchCanNameOne() async throws {
        try await serve(StubSource(hostUp: true), port: 47693) {
            let (filed, ok) = try await call(47693, "/v1/records", method: "POST",
                                             body: #"{"thread": "alpha", "text": "loom", "group": "Notes"}"#, secret: "s3cret")
            #expect(ok == 200 && filed.contains("weave-alpha-notes") && filed.contains("\"indexed\":true"))
            let viaPath = try await call(47693, "/v1/threads/alpha/records", method: "POST", body: #"{"text": "shuttle"}"#, secret: "s3cret").1
            let noThread = try await call(47693, "/v1/records", method: "POST", body: #"{"text": "loom"}"#, secret: "s3cret").1
            let unknown = try await call(47693, "/v1/records", method: "POST", body: #"{"thread": "zeta", "text": "loom"}"#, secret: "s3cret").1
            let empty = try await call(47693, "/v1/records", method: "POST", body: #"{"thread": "alpha", "text": " "}"#, secret: "s3cret").1
            #expect(viaPath == 200 && noThread == 400 && unknown == 404 && empty == 400)
            let (one, found) = try await call(47693, "/v1/search", method: "POST", body: #"{"query": "loom", "thread": "alpha"}"#, secret: "s3cret")
            #expect(found == 200 && one.contains("alpha says loom") && one.contains("\"thread_name\":\"alpha\""))
            let records = try await call(47693, "/v1/threads/alpha/records", secret: "s3cret").1
            #expect(records == 200)
        }
    }
}
