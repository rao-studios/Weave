//
//  FabricService.Start.swift
//  WeaveKit
//
//  Starts (or adopts) an instance's Thread. `restart` stops it first: the only way a running
//  Thread changes the mothership it registered with. A start that finds the Thread running
//  registered elsewhere restarts it too.
//

import Foundation
import Granite

extension FabricService {
    public struct Start: GraniteReducer {
        public typealias Center = FabricService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public let ticket: UUID
            public let name: String
            public let mothership: AIIPorts?
            public let restart: Bool
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            FabricOps.adopt(meta.ticket, for: meta.name, in: &state)
            if state.busy[meta.name] == meta.ticket { state.status[meta.name] = .starting }
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta else { return .none }
            guard let record = state.record(meta.name) else {
                return .run { await FabricService.tickets.fail(meta.ticket, FabricError.notFound(meta.name)) }
            }
            let reseed = state.reseed.contains(meta.name)
            let shape = state.shapes[meta.name]
            let wasRunning = state.status(of: meta.name).isRunning
            return FabricService.work(ticket: meta.ticket, name: meta.name, state: state) { fabric in
                try await FabricService.lane.run {
                    let mustRestart = meta.restart
                        || (wasRunning && FabricOps.needsRestart(record: record, shape: shape, mothership: meta.mothership))
                    if mustRestart || reseed { await FabricOps.stop(record) }
                    let (handle, launched) = try await FabricOps.start(record, mothership: meta.mothership, reseed: reseed)
                    if reseed { fabric.set(.reseeded(record.name)) }
                    fabric.set(.shape(record.name, launched))
                    fabric.set(.status(record.name, .up(pid: handle.pid)))
                    return .status(.up(pid: handle.pid))
                }
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}
