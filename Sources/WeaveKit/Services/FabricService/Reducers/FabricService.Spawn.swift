//
//  FabricService.Spawn.swift
//  WeaveKit
//
//  A new AII: a seeded, provisioned home on the next free port slot, with its config and record.
//  Not started: the caller starts it with the host's mothership ports.
//

import Foundation
import Granite

extension FabricService {
    public struct Spawn: GraniteReducer {
        public typealias Center = FabricService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public let ticket: UUID
            public let name: String
            public let graphBackend: String
            public let woven: Bool
            public let softCap: Int
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            FabricOps.adopt(meta.ticket, for: meta.name, in: &state)
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta else { return .none }
            let snapshot = state
            return FabricService.work(ticket: meta.ticket, name: meta.name, state: state) { fabric in
                let record = try await FabricService.lane.run {
                    try FabricOps.spawn(name: meta.name, graphBackend: meta.graphBackend, woven: meta.woven,
                                        softCap: meta.softCap, state: snapshot)
                }
                fabric.set(.record(record))
                fabric.set(.status(record.name, .stopped(nil)))
                return .record(record)
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}
