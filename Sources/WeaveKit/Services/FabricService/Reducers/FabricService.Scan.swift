//
//  FabricService.Scan.swift
//  WeaveKit
//
//  Registers Weave in the main home, makes the fabric's folder ready, reads every instance in it,
//  and probes each once. Adopts what runs; never starts anything.
//

import Foundation
import Granite

extension FabricService {
    public struct Scan: GraniteReducer {
        public typealias Center = FabricService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public let ticket: UUID
            public let root: String
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            state.scanning = true
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta else { return .none }
            let fabric = Live.service(FabricService.self)
            return .run {
                do {
                    let scan = try FabricOps.scan(root: meta.root)
                    fabric.set(.scanned(scan))
                    for record in scan.records { fabric.set(.probe(record.name, await FabricOps.probe(record))) }
                    await MainQueue.flush()
                    await FabricService.tickets.resolve(meta.ticket, with: .scan(scan))
                } catch {
                    fabric.set(.scanning(false))
                    fabric.set(.failed(FabricOps.message(error)))
                    await MainQueue.flush()
                    await FabricService.tickets.fail(meta.ticket, error)
                }
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}
