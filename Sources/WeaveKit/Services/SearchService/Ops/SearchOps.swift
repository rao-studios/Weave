//
//  SearchOps.swift
//  WeaveKit
//
//  SearchService's bodies: the transitions, and naming each merged hit by the instance whose
//  Thread answered it (the reference's thread id → the host's node → that node's HTTP port →
//  the spawned AII on that port, or the main AII's Thread).
//

import Foundation

public enum SearchOps {
    public typealias State = SearchService.Center.State

    public static func apply(_ kind: SearchService.Set.Meta.Kind, to state: inout State) {
        switch kind {
        case .results(let hits, let graph, let latency, let epoch):
            guard epoch == state.epoch else { return }
            state.hits = hits
            state.graph = graph
            state.latencyMs = latency
            state.searching = false
            state.lastError = nil
        case .failed(let message, let epoch):
            guard epoch == state.epoch else { return }
            state.searching = false
            state.lastError = message
            state.hits = []
            state.graph = nil
        case .clear:
            state = State()
        }
    }

    public static func hits(_ response: SewnSearchResponse, nodes: [HostNode], records: [ThreadRecord], mainThreadHTTP: Int?) -> [SearchHit] {
        zip(response.texts, response.references).enumerated().map { index, pair in
            SearchHit(rank: index + 1, text: pair.0, reference: pair.1,
                      threadName: name(of: pair.1, nodes: nodes, records: records, mainThreadHTTP: mainThreadHTTP))
        }
    }

    public static func name(of reference: PartitionReference, nodes: [HostNode], records: [ThreadRecord], mainThreadHTTP: Int?) -> String? {
        guard let threadId = reference.threadId?.lowercased(),
              let node = nodes.first(where: { $0.threadId.lowercased() == threadId }) else { return nil }
        return HostOps.name(of: node, records: records, mainThreadHTTP: mainThreadHTTP)
    }

    /// The main AII's Thread HTTP port.
    public static func mainThreadHTTP(main: AIIHome = .resolved()) -> Int { AIIConfig.load(home: main).threadPorts.http }

    /// A search failure, said so the person knows what to do.
    public static func explain(_ error: Error) -> String {
        if let http = error as? WeaveHTTPError, http.statusCode == 401 {
            return "The host refused the search without an account. Install an AII build that grants POST /v1/search to a local app (see the README)."
        }
        if case FabricError.noHost? = error as? FabricError { return "No host is up. Choose one in the sidebar." }
        return FabricOps.message(error)
    }
}
