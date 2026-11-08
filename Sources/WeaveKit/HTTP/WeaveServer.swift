//
//  WeaveServer.swift
//  WeaveKit
//
//  Weave's own port (127.0.0.1:47600): a local process asks Weave, Weave asks the host.
//
//    GET  /health        open: Weave, its host, how many AIIs it runs
//    GET  /v1/threads    the spawned AIIs, their ports, and the host's node for each
//    POST /v1/search     {query, top_k?} → the host Sewn's federated search, each hit named by the
//                        Weave instance whose Thread answered it
//
//  PIN:  LOOPBACK. Bound to 127.0.0.1, and a request whose Host is not this Mac is refused (421).
//        With `requireSecret`, /v1/* also wants X-Ambient-Secret = Weave's secret in ~/.rao (401).
//  PIN:  The handlers read nothing of Granite's: a `WeaveGatewaySource` hands them value snapshots
//        and does the search, so the router is tested without a service.
//

import Foundation
import Hummingbird
import Logging

public protocol WeaveGatewaySource: Sendable {
    func health() async -> WeaveHealth
    func threads() async -> WeaveThreads
    func search(_ request: WeaveSearchRequest) async throws -> WeaveSearchResponse
    /// The secret /v1/* must carry; nil refuses every /v1/* call while the gate is on.
    func secret() -> String?
    func served(_ path: String) async
}

public enum WeaveServer {
    public static func router(source: any WeaveGatewaySource, requireSecret: Bool) -> Router<BasicRequestContext> {
        let router = Router()
        router.get("/health") { request, _ -> WeaveHealth in
            try loopback(request)
            await source.served("/health")
            return await source.health()
        }
        router.get("/v1/threads") { request, _ -> WeaveThreads in
            try gate(request, source: source, requireSecret: requireSecret)
            await source.served("/v1/threads")
            return await source.threads()
        }
        router.post("/v1/search") { request, context -> WeaveSearchResponse in
            try gate(request, source: source, requireSecret: requireSecret)
            let body = try await request.decode(as: WeaveSearchRequest.self, context: context)
            guard !body.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw HTTPError(.badRequest, message: "query is empty")
            }
            await source.served("/v1/search")
            do {
                return try await source.search(body)
            } catch FabricError.noHost {
                throw HTTPError(.serviceUnavailable, message: "no host is up: choose one in Weave")
            } catch let error as WeaveHTTPError {
                throw HTTPError(.badGateway, message: "the host answered: \(error.localizedDescription)")
            }
        }
        return router
    }

    public static func application(port: Int, source: any WeaveGatewaySource, requireSecret: Bool,
                                   onRunning: @escaping @Sendable () async -> Void = {}) -> some ApplicationProtocol {
        Application(router: router(source: source, requireSecret: requireSecret),
                    configuration: .init(address: .hostname(LoopbackHTTP.host, port: port), serverName: "Weave"),
                    onServerRunning: { _ in await onRunning() },
                    logger: quietLogger)
    }

    /// The port's own state says whether it listens; a bind failure is thrown. Hummingbird's
    /// routine lines (including a cancellation at every stop) stay out of the app's output.
    static let quietLogger: Logger = {
        var logger = Logger(label: "nyc.rao.weave.port")
        logger.logLevel = .critical
        return logger
    }()

    static func loopback(_ request: Request) throws {
        guard StackSecret.isLoopback(authority: request.head.authority ?? header(request, "Host")) else {
            throw HTTPError(.misdirectedRequest, message: "Weave answers only this Mac")
        }
    }

    /// A header's value by name, any case.
    static func header(_ request: Request, _ name: String) -> String? {
        let wanted = name.lowercased()
        return request.headers.first { $0.name.canonicalName == wanted }?.value
    }

    static func gate(_ request: Request, source: any WeaveGatewaySource, requireSecret: Bool) throws {
        try loopback(request)
        guard requireSecret else { return }
        let presented = header(request, StackSecret.headerName)
        guard StackSecret.matches(presented, secret: source.secret()) else {
            throw HTTPError(.unauthorized, message: "X-Ambient-Secret must be Weave's secret (~/.rao/secrets/weave)")
        }
    }
}
