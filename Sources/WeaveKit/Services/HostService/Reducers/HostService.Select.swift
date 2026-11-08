//
//  HostService.Select.swift
//  WeaveKit
//
//  Makes an AII the host: brings its Sewn up, lets the previous host go, saves the choice in
//  fabric.json, and restarts every running woven Thread whose mothership is not this host's.
//

import Foundation
import Granite

extension HostService {
    public struct Select: GraniteReducer {
        public typealias Center = HostService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public let ticket: UUID
            public let selection: HostSelection
            public let root: String
        }

        @Payload public var meta: Meta?
        @Relay var fabric: FabricService

        public func reduce(state: inout Center.State) {
            guard let meta, state.switching == nil else { return }
            state.switching = meta.ticket
            state.sewn = .starting
            state.lastError = nil
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta else { return .none }
            guard state.switching == meta.ticket else {
                return .run { await HostService.tickets.fail(meta.ticket, FabricError.busy("the host")) }
            }
            let host = Live.service(HostService.self)
            let fabric = self.fabric
            let previous = state.target.map { _ in state.selection }
            return .run {
                do {
                    let snapshot = await MainActor.run { fabric.state }
                    let target = try HostOps.resolve(meta.selection, fabric: snapshot)
                    try await HostOps.bringUp(meta.selection, fabric: snapshot)
                    if let previous, previous != meta.selection { await HostOps.release(previous) }
                    HostOps.save(meta.selection, root: meta.root)
                    host.set(.selected(meta.selection, target))
                    host.set(.sewn(.up))

                    // The running woven Threads registered elsewhere come over to this host.
                    let now = await MainActor.run { fabric.state }
                    var rewoven: [String] = []
                    for record in now.threads where record.woven && now.status(of: record.name).isRunning
                        && FabricOps.needsRestart(record: record, shape: now.shapes[record.name], mothership: target.sewnPorts) {
                        do {
                            try await fabric.restart(record.name, mothership: target.sewnPorts)
                            rewoven.append(record.name)
                        } catch {
                            host.set(.failed("\(record.name) could not move to the new host: \(FabricOps.message(error))"))
                        }
                    }
                    host.set(.rewoven(rewoven))
                    host.set(.switched)
                    await HostOps.poll(host)
                    await MainQueue.flush()
                    await HostService.tickets.resolve(meta.ticket, with: .target(target))
                } catch {
                    let message = FabricOps.message(error)
                    host.set(.sewn(.down(message)))
                    host.set(.failed(message))
                    host.set(.switched)
                    await MainQueue.flush()
                    await HostService.tickets.fail(meta.ticket, error)
                }
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}
