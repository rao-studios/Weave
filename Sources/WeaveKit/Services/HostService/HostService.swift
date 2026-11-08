//
//  HostService.swift
//  WeaveKit
//
//  WHAT: The host: the Sewn the woven Threads register with as their mothership, and whose
//        /v1/search fans a query out to every one of them and merges the answers by score.
//        Select brings the chosen host up (the main AII through AII's supervisor, holding a lease
//        as every Rao app does; a spawned AII by starting `AIIServer sewn` in its home), lets the
//        previous one go, and restarts every running woven Thread that registered elsewhere.
//        Poll reads the host's /v1/threads: the nodes it fans out to.
//  OUT:  `state.target` (where the host listens, whose home), `state.nodes`, `state.sewn`.
//  PIN:  Relays down into FabricService only (the Threads it restarts). The mothership ports go
//        to Fabric in payloads; Fabric never reads this service.
//

import Foundation
import Granite

public struct HostService: GraniteService {
    @Service(.online) public var center: Center
    public init() {}

    static let tickets = VeilTickets<Reply>()
    /// The main AII's supervisor, holding Weave's lease, while the main AII is the host.
    static let supervisors = TransientRegistry<AIISupervisor>()
    /// The Sewn Weave started in a spawned home, by that home's name.
    static let servers = TransientRegistry<ManagedServer>()
    static let tasks = TransientRegistry<Task<Void, Never>>()
}

extension HostService: @unchecked Sendable {}

extension HostService {
    public func set(_ kind: Set.Meta.Kind) {
        let service = self
        onMain { service.center.set.send(Set.Meta(kind: kind)) }
    }

    /// Makes `selection` the host and re-weaves the running Threads to it.
    @discardableResult
    public func select(_ selection: HostSelection, root: String) async throws -> HostTarget {
        let ticket = await Self.tickets.open()
        let service = self
        onMain { service.center.select.send(Select.Meta(ticket: ticket.id, selection: selection, root: root)) }
        guard case .target(let target) = try await Self.tickets.wait(ticket.id) else { throw FabricError.noHost }
        return target
    }

    /// The host `fabric.json` names (the main AII when none), selected.
    @discardableResult
    public func restore(root: String) async throws -> HostTarget {
        let saved = FabricRoot.load(root: FabricRoot.url(root))?.host ?? .main
        return try await select(saved, root: root)
    }

    /// Reads the host's nodes and health now.
    public func poll() async {
        await HostOps.poll(self)
    }

    /// Starts the poll loop every `interval` seconds, or stops it (nil).
    public func watch(interval: Double?) {
        let service = self
        onMain { service.center.watch.send(Watch.Meta(interval: interval)) }
    }

    /// Quit: Weave's lease on the main AII goes; a Sewn Weave started in a spawned home stops only
    /// when `stopSpawned` (it keeps serving the woven Threads otherwise, and is adopted next launch).
    public static func shutdownSync(stopSpawned: Bool, records: [ThreadRecord]) {
        tasks.removeAll()
        supervisors.remove("main")?.shutdownSync()
        guard stopSpawned else { return }
        for record in records { ManagedServer.stopRecordedSync(record.aiiHome.sewnRunRecord, grace: 1.5) }
    }
}
