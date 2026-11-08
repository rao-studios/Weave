//
//  WeaveServer.swift
//  WeaveKit
//
//  Weave's own port (127.0.0.1:47600): a forwarder to the AIIs it spawned and to the host (see
//  Forwarder.swift for the routing spec). Weave's own routes are only these two:
//
//    GET  /health        open: Weave, its host, how many AIIs it runs
//    GET  /v1/threads    the AIIs a request can route to: each one's id (what `weave.aii` names), its
//                        label, whether it is up, and its `direct` Thread URL and key file for a
//                        request that goes straight to it
//
//  Everything else is the AII's own API, forwarded:
//
//    POST /v1/batch/embeddings, /v1/search, /v1/library, /v1/graph, GET /v1/stats    to an AII's Thread
//    POST /v1/search without an AII                                                   to the host's Sewn
//
//  PIN:  LOOPBACK. Bound to 127.0.0.1, and a request whose Host is not this Mac is refused (421).
//        With `requireSecret`, /v1/* also wants X-Ambient-Secret = Weave's secret in ~/.rao (401).
//

import Foundation
import HTTPTypes
import Hummingbird
import Logging
import NIOCore
import NIOFoundationCompat

public protocol WeaveGatewaySource: Sendable {
    func health() async -> WeaveHealth
    func threads() async -> WeaveThreads
    /// The Thread of the AII with this id; FabricError.notFound when there is none.
    func route(aii: String) async throws -> ForwardTarget
    /// The host's Sewn, and the AII id of each Thread id it fans out to; FabricError.noHost when down.
    func host() async throws -> (target: ForwardTarget, names: [String: String])
    /// The secret /v1/* must carry; nil refuses every /v1/* call while the gate is on.
    func secret() -> String?
    func served(_ path: String) async
}

public enum WeaveServer {
    /// What a forwarded request may carry.
    static let maxBody = 32 << 20

    public static func router(source: any WeaveGatewaySource, requireSecret: Bool,
                              transport: @escaping ThreadHTTPClient.Transport = LoopbackHTTP.send) -> Router<BasicRequestContext> {
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
        for route in Forwarder.threadRoutes {
            let handler: @Sendable (Request, BasicRequestContext) async throws -> Response = { request, context in
                try gate(request, source: source, requireSecret: requireSecret)
                var request = request
                let raw = route.method == "GET" ? nil : Data(buffer: try await request.collectBody(upTo: maxBody))
                await source.served(route.path)
                return try await forward(route.method, route.path, raw: raw, request: request, source: source, transport: transport)
            }
            if route.method == "GET" { router.get(RouterPath(route.path), use: handler) } else { router.post(RouterPath(route.path), use: handler) }
        }
        return router
    }

    /// One forwarded request: split off the routing spec, pick the target, fill the owner, send, and
    /// answer with the target's status and body (plus `weave`, on success).
    static func forward(_ method: String, _ path: String, raw: Data?, request: Request, source: any WeaveGatewaySource,
                        transport: @escaping ThreadHTTPClient.Transport) async throws -> Response {
        let routing: Forwarder.Routing
        var body: [String: Any]?
        do {
            (routing, body) = try Forwarder.split(raw, header: header(request, "X-Weave-AII"),
                                                   query: request.uri.queryParameters.get("aii"))
        } catch Forwarder.Failure.badBody(let message) {
            throw HTTPError(.badRequest, message: message)
        }

        // A search that names no AII: the host's Sewn, across every woven AII.
        guard let aii = routing.aii else {
            guard path == "/v1/search" else {
                throw HTTPError(.badRequest, message: "name the AII: \"weave\": {\"aii\": id} in the body, the X-Weave-AII header or ?aii= (ids: GET /v1/threads)")
            }
            var object = body ?? [:]
            Forwarder.fillSewn(&object)
            let host: (target: ForwardTarget, names: [String: String])
            do { host = try await source.host() } catch {
                throw HTTPError(.serviceUnavailable, message: "no host is up for a search across every AII: choose one in Weave")
            }
            let (data, status) = try await send(method, path, Forwarder.encode(object), host.target, transport)
            let weave: [String: Any] = ["routed_to": "host", "threads": host.names]
            return respond(status, (200..<300).contains(status) ? Forwarder.annotate(data, with: weave) : data)
        }

        let target: ForwardTarget
        do { target = try await source.route(aii: aii) } catch {
            throw HTTPError(.notFound, message: "no AII with id \(aii): GET /v1/threads lists them; main is the main AII")
        }
        var owner = WeaveIdentity.owner
        var forwarded: Data?
        if var object = body {
            owner = Forwarder.fillOwner(&object, path: path)
            body = object
            forwarded = Forwarder.encode(object)
        }
        let (data, status) = try await send(method, path, forwarded, target, transport)
        guard (200..<300).contains(status) else { return respond(status, data) }

        var weave: [String: Any] = ["aii": aii, "owner_id": owner]
        if owner != WeaveIdentity.owner {
            weave["note"] = "filed or read as \(owner): a search across every AII answers for \(WeaveIdentity.owner) only"
        }
        if path == "/v1/batch/embeddings", routing.wait, let object = body {
            weave["indexed"] = await Forwarder.waitUntilSearchable(Forwarder.inputs(object), owner: owner, target: target, transport: transport)
        }
        return respond(status, Forwarder.annotate(data, with: weave))
    }

    static func send(_ method: String, _ path: String, _ body: Data?, _ target: ForwardTarget,
                     _ transport: @escaping ThreadHTTPClient.Transport) async throws -> (Data, Int) {
        do { return try await Forwarder.send(method: method, path: path, body: body, to: target, transport: transport) }
        catch { throw HTTPError(.badGateway, message: "\(target.aii.map { "AII \($0)" } ?? "the host") is not answering: start it in Weave") }
    }

    static func respond(_ status: Int, _ data: Data) -> Response {
        var headers = HTTPFields()
        headers[.contentType] = "application/json"
        return Response(status: HTTPResponse.Status(code: status), headers: headers, body: ResponseBody(byteBuffer: ByteBuffer(data: data)))
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
        guard StackSecret.matches(header(request, StackSecret.headerName), secret: source.secret()) else {
            throw HTTPError(.unauthorized, message: "X-Ambient-Secret must be Weave's secret (~/.rao/secrets/weave)")
        }
    }
}
