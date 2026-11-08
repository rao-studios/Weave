//
//  ExplorerService.Load.swift
//  WeaveKit
//
//  One request to the selected Thread. Marks its pane loading; the answer is written for the
//  Thread it was asked of and dropped if another was selected meanwhile.
//

import Foundation
import Granite

extension ExplorerService {
    public struct Load: GraniteReducer {
        public typealias Center = ExplorerService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public let ticket: UUID
            public let ref: ThreadRef
            public let request: Request
        }

        @Payload public var meta: Meta?
        @Relay var fabric: FabricService

        public func reduce(state: inout Center.State) {
            guard let meta, state.selected == meta.ref else { return }
            state.loading.insert(meta.request.pane)
            state.errors[meta.request.pane] = nil
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta else { return .none }
            let explorer = Live.service(ExplorerService.self)
            let records = fabric.state.threads
            return .run {
                do {
                    let endpoint = try ExplorerOps.endpoint(meta.ref, records: records)
                    try await ExplorerOps.perform(meta.request, ref: meta.ref, endpoint: endpoint, explorer: explorer)
                    await MainQueue.flush()
                    await ExplorerService.tickets.resolve(meta.ticket, with: true)
                } catch {
                    explorer.set(.failed(meta.ref, meta.request.pane, FabricOps.message(error)))
                    await MainQueue.flush()
                    await ExplorerService.tickets.resolve(meta.ticket, with: false)
                }
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}
