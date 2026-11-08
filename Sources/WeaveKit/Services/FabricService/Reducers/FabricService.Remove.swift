//
//  FabricService.Remove.swift
//  WeaveKit
//
//  Stops an instance's Thread and deletes its home: its index, its secrets, its records. A home
//  under the fabric's folder is Weave's; the shared models folder is a link and is not touched.
//

import Foundation
import Granite

extension FabricService {
    public struct Remove: GraniteReducer {
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
                    // Only a folder holding this record's weave.json is removed, with its kept home.
                    try FabricRoot.remove(record)
                    fabric.set(.removed(record.name))
                    await FabricOps.measure(fabric, root: record.fabricRoot.path)
                    return .done
                }
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}
