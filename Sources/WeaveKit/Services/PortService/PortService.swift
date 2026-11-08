//
//  PortService.swift
//  WeaveKit
//
//  WHAT: Weave's own port on 127.0.0.1 (47600 unless Settings say otherwise): GET /health,
//        GET /v1/threads, POST /v1/search, so a local process can ask Weave and Weave asks the
//        host. The server is Hummingbird; its Task is a resident.
//  PIN:  The handlers read the services through `LiveGatewaySource`, which hops to main for value
//        snapshots; no reducer here stores a relay.
//

import Foundation
import Granite

public struct PortService: GraniteService {
    @Service(.online) public var center: Center
    public init() {}

    static let tasks = TransientRegistry<Task<Void, Never>>()
}

extension PortService: @unchecked Sendable {}

extension PortService {
    public func set(_ kind: Set.Meta.Kind) {
        let service = self
        onMain { service.center.set.send(Set.Meta(kind: kind)) }
    }

    /// Listens on `port` (restarting the server when it already listens).
    public func start(port: Int, requireSecret: Bool) {
        let service = self
        onMain { service.center.serve.send(Serve.Meta(port: port, requireSecret: requireSecret)) }
    }

    public func stop() {
        let service = self
        onMain { service.center.serve.send(Serve.Meta(port: nil, requireSecret: true)) }
    }
}
