//
//  FabricService.Label.swift
//  WeaveKit
//
//  Gives an instance's AII a label: written into its home (`aii/label.json`, AII's AIILabel), where
//  the AII says it on /health and Weave reads it back as the name it shows. A running Thread says the
//  new label at its next /health; nothing restarts. The record's name stays its handle.
//

import Foundation
import Granite

extension FabricService {
    public struct Label: GraniteReducer {
        public typealias Center = FabricService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public let ticket: UUID
            public let name: String
            public let label: String
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
                let label = try AIILabel.write(meta.label, home: record.aiiHome)
                fabric.set(.label(record.name, label))
                return .done
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}
