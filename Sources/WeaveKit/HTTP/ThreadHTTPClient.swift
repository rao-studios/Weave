//
//  ThreadHTTPClient.swift
//  WeaveKit
//
//  One Thread's HTTP routes, asked with Weave's secret in that Thread's home, so every read and
//  write is cut to Weave's lane. Deposits are filed as `local-weave`, the owner a federated search
//  through the host answers for.
//

import Foundation

public struct ThreadHTTPClient: Sendable {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, Int)

    public let port: Int
    public let secret: String
    public let transport: Transport

    public init(port: Int, secret: String, transport: @escaping Transport = LoopbackHTTP.send) {
        self.port = port
        self.secret = secret
        self.transport = transport
    }

    /// The client for a Thread whose home and HTTP port are known.
    public static func forHome(_ home: AIIHome, port: Int, transport: @escaping Transport = LoopbackHTTP.send) throws -> ThreadHTTPClient {
        guard let secret = try home.readSecret(for: WeaveIdentity.app) else { throw WeaveHTTPError.noSecret }
        return ThreadHTTPClient(port: port, secret: secret, transport: transport)
    }

    private func call<T: Decodable>(_ type: T.Type, _ path: String, method: String = "POST", body: Data? = nil,
                                    timeout: TimeInterval = 30) async throws -> T {
        try await LoopbackHTTP.json(T.self, LoopbackHTTP.request(port: port, path: path, method: method, body: body, secret: secret,
                                                                 timeout: timeout), transport: transport)
    }

    public func stats() async throws -> AIIStats {
        try await call(AIIStats.self, "/v1/stats", method: "GET")
    }

    public func library(ownerId: String = WeaveIdentity.owner) async throws -> [LibraryGroup] {
        struct Body: Encodable { let owner_id: String; let include_available: Bool }
        return try await call(LibraryResponse.self, "/v1/library",
                              body: LoopbackHTTP.encode(Body(owner_id: ownerId, include_available: true))).groups
    }

    public func graph(ownerId: String = WeaveIdentity.owner, entity: String?, query: String?, hops: Int, limit: Int = 40) async throws -> GraphSnapshot {
        struct Thread: Encodable { let owner_id: String }
        struct Body: Encodable { let thread: Thread; let entity: String?; let query: String?; let hops: Int; let limit: Int; let include_documents: Bool }
        let body = Body(thread: Thread(owner_id: ownerId), entity: entity.flatMap { $0.isEmpty ? nil : $0 },
                        query: query.flatMap { $0.isEmpty ? nil : $0 }, hops: max(1, hops), limit: limit, include_documents: false)
        return try await call(GraphSnapshot.self, "/v1/graph", body: LoopbackHTTP.encode(body), timeout: 60)
    }

    public func search(_ query: String, ownerId: String = WeaveIdentity.owner, topK: Int = 10) async throws -> ThreadSearchResponse {
        struct Thread: Encodable { let owner_id: String; let scope: String; let top_k: Int }
        struct Body: Encodable { let query: String; let thread: Thread }
        let body = Body(query: query, thread: Thread(owner_id: ownerId, scope: "global", top_k: max(1, topK)))
        return try await call(ThreadSearchResponse.self, "/v1/search", body: LoopbackHTTP.encode(body), timeout: 60)
    }

    /// Files `text` under `group` as `ownerId`; the Thread embeds it and extracts its graph on device.
    public func deposit(_ text: String, name: String?, groupID: String, groupLabel: String,
                        ownerId: String = WeaveIdentity.owner) async throws -> DepositReceipt {
        struct Group: Encodable { let id: String; let label: String; let owner_id: String }
        struct Thread: Encodable { let owner_id: String; let group: Group }
        struct Body: Encodable { let inputs: [String]; let sanitize: Bool; let thread: Thread; let names: [String?]? }
        let body = Body(inputs: [text], sanitize: true,
                        thread: Thread(owner_id: ownerId, group: Group(id: groupID, label: groupLabel, owner_id: ownerId)),
                        names: name.map { [$0] })
        return try await call(DepositReceipt.self, "/v1/batch/embeddings", body: LoopbackHTTP.encode(body), timeout: 180)
    }
}

/// A Thread's /health, proved with Weave's secret: whether it is ours, and what its embedder and
/// extractor are doing.
public struct ThreadHealth: Sendable, Equatable {
    public var verdict: StackVerdict
    public var embedder: ThreadEmbedderState?
    public var extractor: String?

    public init(verdict: StackVerdict, embedder: ThreadEmbedderState?, extractor: String?) {
        self.verdict = verdict; self.embedder = embedder; self.extractor = extractor
    }

    public static func probe(home: AIIHome, port: Int, timeout: TimeInterval = 2) async -> ThreadHealth {
        guard let secret = try? home.readSecret(for: WeaveIdentity.app) else { return ThreadHealth(verdict: .down, embedder: nil, extractor: nil) }
        let url = URL(string: "http://127.0.0.1:\(port)/health")!
        let (verdict, body) = await StackProbe.challengeWithBody(url: url, secret: secret, identity: .app(WeaveIdentity.app), timeout: timeout)
        guard let body else { return ThreadHealth(verdict: verdict, embedder: nil, extractor: nil) }
        return ThreadHealth(verdict: verdict, embedder: ThreadEmbedderState.parse(healthBody: body), extractor: extractorLine(body))
    }

    /// The extractor block's phase and backend, as one short line (`ready · mlx`).
    static func extractorLine(_ body: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let extractor = object["extractor"] as? [String: Any] else { return nil }
        let parts = [extractor["phase"], extractor["backend"], extractor["state"]].compactMap { $0 as? String }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
