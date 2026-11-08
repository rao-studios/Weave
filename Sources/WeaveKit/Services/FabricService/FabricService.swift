//
//  FabricService.swift
//  WeaveKit
//
//  WHAT: The fabric: the AII homes Weave spawned under its folder and their `AIIServer thread`
//        processes. Scan reads the folder and adopts what runs; Spawn seeds and provisions a home
//        (FabricSeeding) on a free port slot; Start/Stop/Restart run its Thread through AII's
//        ManagedServer; Weave flips whether it registers with the host; Remove deletes the home;
//        Watch probes every Thread's /health and counts on a loop.
//  OUT:  `state.threads`, each one's status, embedder and counts, and the launch shape it runs with.
//  PIN:  A leaf: no reducer here holds a relay. The host's mothership ports arrive in payloads, so
//        HostService (above) can restart Threads here without this service ever reading it.
//  PIN:  One verb per instance at a time: `reduce` adopts the request's ticket into `busy` only when
//        the instance is idle, and the effect goes on only when the committed state carries it.
//        Spawns and starts also run one at a time (`lane`): each loads models.
//

import Foundation
import Granite

public struct FabricService: GraniteService {
    @Service(.online) public var center: Center
    public init() {}

    static let tickets = VeilTickets<Reply>()
    /// The ManagedServer of each Thread this process launched or adopted, by name.
    static let servers = TransientRegistry<ManagedServer>()
    /// The watch loop.
    static let tasks = TransientRegistry<Task<Void, Never>>()
    static let lane = VeilLane()

    public static let defaultSoftCap = 8
}

extension FabricService: @unchecked Sendable {}

extension FabricService {
    public func set(_ kind: Set.Meta.Kind) {
        let service = self
        onMain { service.center.set.send(Set.Meta(kind: kind)) }
    }

    private func ticketed(_ send: @escaping @Sendable (FabricService, UUID) -> Void) async throws -> Reply {
        let ticket = await Self.tickets.open()
        let service = self
        onMain { send(service, ticket.id) }
        return try await Self.tickets.wait(ticket.id)
    }

    /// Registers Weave in the main home, makes the folder ready, reads every instance and probes it.
    @discardableResult
    public func scan(root: String) async throws -> FabricScan {
        guard case .scan(let scan) = try await ticketed({ $0.center.scan.send(Scan.Meta(ticket: $1, root: root)) }) else {
            throw FabricError.notFound(root)
        }
        return scan
    }

    /// A new AII on the next free slot, provisioned but not started.
    public func spawn(name: String, graphBackend: String, woven: Bool = true, softCap: Int = defaultSoftCap) async throws -> ThreadRecord {
        let reply = try await ticketed {
            $0.center.spawn.send(Spawn.Meta(ticket: $1, name: name, graphBackend: graphBackend, woven: woven, softCap: softCap))
        }
        guard case .record(let record) = reply else { throw FabricError.notFound(name) }
        return record
    }

    /// Starts (or adopts) `name`'s Thread; a woven one registers with `mothership`.
    public func start(_ name: String, mothership: AIIPorts?) async throws {
        _ = try await ticketed { $0.center.start.send(Start.Meta(ticket: $1, name: name, mothership: mothership, restart: false)) }
    }

    /// Stops and starts again: how a Thread changes the mothership it registered with.
    public func restart(_ name: String, mothership: AIIPorts?) async throws {
        _ = try await ticketed { $0.center.start.send(Start.Meta(ticket: $1, name: name, mothership: mothership, restart: true)) }
    }

    public func stop(_ name: String) async throws {
        _ = try await ticketed { $0.center.stop.send(Stop.Meta(ticket: $1, name: name)) }
    }

    /// Weaves `name` in (registers with `mothership`) or out (standalone); a running Thread restarts.
    public func weave(_ name: String, woven: Bool, mothership: AIIPorts?) async throws {
        _ = try await ticketed { $0.center.weave.send(Weave.Meta(ticket: $1, name: name, woven: woven, mothership: mothership)) }
    }

    /// Stops `name` and deletes its home.
    public func remove(_ name: String) async throws {
        _ = try await ticketed { $0.center.remove.send(Remove.Meta(ticket: $1, name: name)) }
    }

    /// Starts the probe loop every `interval` seconds, or stops it (nil).
    public func watch(interval: Double?) {
        let service = self
        onMain { service.center.watch.send(Watch.Meta(interval: interval)) }
    }

    /// The fabric's size on disk, now.
    public func measure() async {
        let root = await MainActor.run { state.root }
        guard !root.isEmpty else { return }
        await FabricOps.measure(self, root: root)
    }

    /// One probe of every Thread now.
    public func tick() async {
        await FabricOps.tick(self)
    }

    /// Stops every Thread this fabric knows, synchronously (quit, when asked to).
    public static func stopAllSync(records: [ThreadRecord]) {
        for record in records { ManagedServer.stopRecordedSync(record.aiiHome.threadRunRecord, grace: 1.5) }
    }
}
