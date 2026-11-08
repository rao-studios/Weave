//
//  SearchService.Query.swift
//  WeaveKit
//

import Foundation
import Granite

extension SearchService {
    public struct Query: GraniteReducer {
        public typealias Center = SearchService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public let ticket: UUID
            public let text: String
            public let topK: Int
        }

        @Payload public var meta: Meta?
        @Relay var host: HostService
        @Relay var fabric: FabricService

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            state.epoch += 1
            state.query = meta.text
            state.searching = true
            state.lastError = nil
        }

        public func effect(state: Center.State) -> GraniteEffect {
            guard let meta else { return .none }
            let search = Live.service(SearchService.self)
            let epoch = state.epoch
            let target = host.state.target
            let nodes = host.state.nodes
            let records = fabric.state.threads
            return .run {
                let started = Date()
                do {
                    guard let target else { throw FabricError.noHost }
                    let response = try await SewnHTTPClient.forTarget(target).search(meta.text, topK: meta.topK)
                    let hits = SearchOps.hits(response, nodes: nodes, records: records, mainThreadHTTP: SearchOps.mainThreadHTTP())
                    search.set(.results(hits, response.graph, latencyMs: Date().timeIntervalSince(started) * 1000, epoch: epoch))
                    await MainQueue.flush()
                    await SearchService.tickets.resolve(meta.ticket, with: hits)
                } catch {
                    search.set(.failed(SearchOps.explain(error), epoch: epoch))
                    await MainQueue.flush()
                    await SearchService.tickets.fail(meta.ticket, error)
                }
            }
        }

        public var thread: DispatchQueue? { .main }
    }
}
