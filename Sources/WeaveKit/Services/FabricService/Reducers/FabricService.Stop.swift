//
//  FabricService.Stop.swift
//  WeaveKit
//

import Foundation
import Granite

extension FabricService {
    public struct Stop: GraniteReducer {
        public typealias Center = FabricService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public let ticket: UUID
            public let name: String
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            FabricOps.adopt(meta.ticket, for: meta.name, in: &state)
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta else { return .none }
            guard let record = state.record(meta.name) else {
                return .run { await FabricService.tickets.fail(meta.ticket, FabricError.notFound(meta.name)) }
            }
            return FabricService.work(ticket: meta.ticket, name: meta.name, state: state) { fabric in
                try await FabricService.lane.run {
                    await FabricOps.stop(record)
                    fabric.set(.shape(record.name, nil))
                    fabric.set(.status(record.name, .stopped(nil)))
                    return .status(.stopped(nil))
                }
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}
