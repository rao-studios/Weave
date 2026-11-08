//
//  ExplorerOps.swift
//  WeaveKit
//
//  ExplorerService's bodies: the transitions, where a Thread listens, and each request.
//

import Foundation

public enum ExplorerOps {
    public typealias State = ExplorerService.Center.State

    public static func apply(_ kind: ExplorerService.Set.Meta.Kind, to state: inout State) {
        switch kind {
        case .selected(let ref):
            guard ref != state.selected else { return }
            state = State()
            state.selected = ref
        case .stats(let ref, let stats, let health):
            guard ref == state.selected else { return }
            state.stats = stats
            state.embedder = health.embedder
            state.extractor = health.extractor
            state.loading.remove(.stats)
        case .library(let ref, let groups):
            guard ref == state.selected else { return }
            state.library = groups.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
            state.loading.remove(.library)
        case .graph(let ref, let graph):
            guard ref == state.selected else { return }
            state.graph = graph
            state.loading.remove(.graph)
        case .hits(let ref, let hits):
            guard ref == state.selected else { return }
            state.hits = hits
            state.loading.remove(.search)
        case .deposited(let ref, let message):
            guard ref == state.selected else { return }
            state.lastDeposit = message
            state.loading.remove(.deposit)
        case .log(let ref, let lines):
            guard ref == state.selected else { return }
            state.log = lines
            state.loading.remove(.log)
        case .failed(let ref, let pane, let message):
            guard ref == state.selected else { return }
            state.errors[pane] = message
            state.loading.remove(pane)
        case .clearAll:
            state = State()
        }
    }

    public struct Endpoint: Sendable, Equatable {
        public var home: AIIHome
        public var threadHTTP: Int
        public var label: String
    }

    public static func endpoint(_ ref: ThreadRef, records: [ThreadRecord], main: AIIHome = .resolved()) throws -> Endpoint {
        switch ref {
        case .main:
            return Endpoint(home: main, threadHTTP: AIIConfig.load(home: main).threadPorts.http, label: "main AII")
        case .spawned(let name):
            guard let record = records.first(where: { $0.name == name }) else { throw FabricError.notFound(name) }
            return Endpoint(home: record.aiiHome, threadHTTP: record.threadHTTP, label: name)
        }
    }

    /// The group a deposit into `ref` is filed under.
    public static func depositGroup(_ ref: ThreadRef) -> (id: String, label: String) {
        switch ref {
        case .main: return ("weave-main", "Weave · main AII")
        case .spawned(let name): return ("weave-\(name)", "Weave · \(name)")
        }
    }

    static func perform(_ request: ExplorerService.Request, ref: ThreadRef, endpoint: Endpoint, explorer: ExplorerService) async throws {
        if case .log = request {
            explorer.set(.log(ref, tail(endpoint.home.threadLogFile, lines: 200)))
            return
        }
        let client = try ThreadHTTPClient.forHome(endpoint.home, port: endpoint.threadHTTP)
        switch request {
        case .stats:
            async let health = ThreadHealth.probe(home: endpoint.home, port: endpoint.threadHTTP)
            let stats = try await client.stats()
            explorer.set(.stats(ref, stats, await health))
        case .library:
            explorer.set(.library(ref, try await client.library()))
        case .graph(let entity, let query, let hops):
            explorer.set(.graph(ref, try await client.graph(entity: entity, query: query, hops: hops)))
        case .search(let query, let topK):
            explorer.set(.hits(ref, ThreadHit.zip(try await client.search(query, topK: topK))))
        case .deposit(let text, let name):
            let group = depositGroup(ref)
            let receipt = try await client.deposit(text, name: name, groupID: group.id, groupLabel: group.label)
            let words = text.split(whereSeparator: \.isWhitespace).count
            explorer.set(.deposited(ref, receipt.success
                ? "Filed \(words) words into \(group.label) as \(WeaveIdentity.owner). The Thread embeds and extracts its graph now."
                : "The Thread did not accept the deposit."))
        case .log:
            break
        }
    }

    /// The last `lines` lines of a log file.
    public static func tail(_ url: URL, lines: Int) -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return ["No log at \(url.path) yet."] }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let window: UInt64 = 64 * 1024
        try? handle.seek(toOffset: size > window ? size - window : 0)
        let data = (try? handle.readToEnd()) ?? Data()
        let text = String(decoding: data, as: UTF8.self)
        return Array(text.split(separator: "\n", omittingEmptySubsequences: true).suffix(lines).map(String.init))
    }
}
