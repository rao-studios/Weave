//
//  SearchService.swift
//  WeaveKit
//
//  WHAT: The federated query the Search page asks: one POST /v1/search to the host's Sewn, which
//        fans it out to every Thread in Weave's scope (the woven spawned AIIs, and the main AII's
//        Thread when the main AII is the host) and merges the partitions by score. Each hit is
//        named by the Weave instance whose Thread answered it.
//  PIN:  Relays down into HostService (the target, the nodes) and FabricService (the names).
//

import Foundation
import Granite

public struct SearchService: GraniteService {
    @Service(.online) public var center: Center
    public init() {}

    static let tickets = VeilTickets<[SearchHit]>()
}

extension SearchService: @unchecked Sendable {}

extension SearchService {
    public func set(_ kind: Set.Meta.Kind) {
        let service = self
        onMain { service.center.set.send(Set.Meta(kind: kind)) }
    }

    @discardableResult
    public func query(_ text: String, topK: Int = 10) async throws -> [SearchHit] {
        let ticket = await Self.tickets.open()
        let service = self
        onMain { service.center.query.send(Query.Meta(ticket: ticket.id, text: text, topK: topK)) }
        return try await Self.tickets.wait(ticket.id)
    }
}
