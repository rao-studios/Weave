//
//  ExplorerService.swift
//  WeaveKit
//
//  WHAT: One Thread at a time, read and written the way Weave's lane allows: its counts and
//        embedder, its library, its graph, a search of it alone, a deposit into it (embedded and
//        graph-extracted on device by that Thread), and its log.
//  PIN:  Every call carries Weave's secret in that Thread's home, so the main AII's Thread shows
//        only what Weave filed there, never another app's lane.
//  PIN:  Relays down into FabricService (a spawned Thread's home and port).
//

import Foundation
import Granite

public struct ExplorerService: GraniteService {
    @Service(.online) public var center: Center
    public init() {}

    static let tickets = VeilTickets<Bool>()
}

extension ExplorerService: @unchecked Sendable {}

extension ExplorerService {
    public func set(_ kind: Set.Meta.Kind) {
        let service = self
        onMain { service.center.set.send(Set.Meta(kind: kind)) }
    }

    /// Shows `ref` (clearing what was read of the last one).
    public func select(_ ref: ThreadRef?) { set(.selected(ref)) }

    /// Asks `ref`'s Thread; answers whether the call succeeded (the state holds the result).
    @discardableResult
    public func load(_ request: Request, on ref: ThreadRef) async -> Bool {
        let ticket = await Self.tickets.open()
        let service = self
        onMain { service.center.load.send(Load.Meta(ticket: ticket.id, ref: ref, request: request)) }
        return (try? await Self.tickets.wait(ticket.id)) ?? false
    }

    /// Stats and the library, the first two panes, together.
    public func refresh(_ ref: ThreadRef) async {
        async let stats = load(.stats, on: ref)
        async let library = load(.library, on: ref)
        _ = await (stats, library)
    }
}
