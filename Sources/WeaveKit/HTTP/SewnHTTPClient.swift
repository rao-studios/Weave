//
//  SewnHTTPClient.swift
//  WeaveKit
//
//  The host's Sewn: one federated search across every Thread in Weave's scope. Asked with Weave's
//  secret in the host's home and no bearer, which the AII grants on POST /v1/search (Weave's
//  prerequisite in the AII repo); the answer is filed for Weave's no-account owner, `local-weave`.
//

import Foundation

public struct SewnHTTPClient: Sendable {
    public typealias Transport = ThreadHTTPClient.Transport

    public let port: Int
    public let secret: String
    public let transport: Transport

    public init(port: Int, secret: String, transport: @escaping Transport = LoopbackHTTP.send) {
        self.port = port
        self.secret = secret
        self.transport = transport
    }

    public static func forTarget(_ target: HostTarget, transport: @escaping Transport = LoopbackHTTP.send) throws -> SewnHTTPClient {
        guard let secret = target.secret() else { throw WeaveHTTPError.noSecret }
        return SewnHTTPClient(port: target.sewnPorts.http, secret: secret, transport: transport)
    }

    /// The request body Sewn's /v1/search decodes: its owner is overwritten with the lane's owner.
    public static func body(query: String, topK: Int) -> Data {
        struct Sewn: Encodable { let owner_id: String; let scope: String }
        struct Body: Encodable { let query: String; let top_k: Int; let sewn: Sewn }
        return LoopbackHTTP.encode(Body(query: query, top_k: max(1, topK), sewn: Sewn(owner_id: WeaveIdentity.owner, scope: "global")))
    }

    public func search(_ query: String, topK: Int = 10) async throws -> SewnSearchResponse {
        let request = LoopbackHTTP.request(port: port, path: "/v1/search", body: Self.body(query: query, topK: topK), secret: secret, timeout: 90)
        return try await LoopbackHTTP.json(SewnSearchResponse.self, request, transport: transport)
    }
}
