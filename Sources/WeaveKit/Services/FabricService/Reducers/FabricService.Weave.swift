//
//  FabricService.Weave.swift
//  WeaveKit
//
//  Weaves an instance in (its Thread registers with the host's Sewn) or out (it runs standalone).
//  The record keeps the choice; a running Thread restarts, since it reads its mothership at launch.
//

import Foundation
import Granite

extension FabricService {
    public struct Weave: GraniteReducer {
        public typealias Center = FabricService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public let ticket: UUID
            public let name: String
            public let woven: Bool
            public let mothership: AIIPorts?
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            FabricOps.adopt(meta.ticket, for: meta.name, in: &state)
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta else { return .none }
            guard let current = state.record(meta.name) else {
                return .run { await FabricService.tickets.fail(meta.ticket, FabricError.notFound(meta.name)) }
            }
            let running = state.status(of: meta.name).isRunning
            let reseed = state.reseed.contains(meta.name)
            var changed = current
            changed.woven = meta.woven
            let record = changed
            return FabricService.work(ticket: meta.ticket, name: meta.name, state: state) { fabric in
                try record.write()
                fabric.set(.record(record))
                guard running else { return .done }
                return try await FabricService.lane.run {
                    fabric.set(.status(record.name, .starting))
                    await FabricOps.stop(record)
                    let (handle, launched) = try await FabricOps.start(record, mothership: meta.mothership, reseed: reseed)
                    fabric.set(.shape(record.name, launched))
                    fabric.set(.status(record.name, .up(pid: handle.pid)))
                    return .status(.up(pid: handle.pid))
                }
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}
