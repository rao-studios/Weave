//
//  PortOps.swift
//  WeaveKit
//
//  PortService's transitions, and what the port answers, built from value snapshots of the
//  host and the fabric.
//

import Foundation

public enum PortOps {
    public typealias State = PortService.Center.State

    public static func apply(_ kind: PortService.Set.Meta.Kind, to state: inout State) {
        switch kind {
        case .listening(let on, let generation):
            guard generation == state.generation else { return }
            state.listening = on
        case .served(let path, let date):
            state.served += 1
            state.lastPath = path
            state.lastRequest = date
        case .failed(let message, let generation):
            guard generation == state.generation else { return }
            state.listening = false
            state.lastError = message
        case .clear:
            state = State()
        }
    }

    public struct Snapshot: Sendable {
        public var port: Int
        public var host: HostService.Center.State
        public var fabric: FabricService.Center.State

        public init(port: Int, host: HostService.Center.State, fabric: FabricService.Center.State) {
            self.port = port; self.host = host; self.fabric = fabric
        }

        var hostInfo: WeaveHostInfo? { host.target.map { WeaveHostInfo(target: $0, up: host.sewn.isUp) } }
    }

    public static func health(_ snapshot: Snapshot) -> WeaveHealth {
        WeaveHealth(status: "ok", app: WeaveIdentity.app.rawValue, port: snapshot.port, host: snapshot.hostInfo,
                    threads: snapshot.fabric.threads.count)
    }

    public static func threads(_ snapshot: Snapshot) -> WeaveThreads {
        let entries = snapshot.fabric.threads.map { record -> WeaveThreadEntry in
            let node = snapshot.host.nodes.first { $0.httpPort == record.threadHTTP }.map {
                WeaveThreadEntry.Node(threadId: $0.threadId, isActive: $0.isActive, acceptingStorage: $0.acceptingStorage)
            }
            let status = snapshot.fabric.status(of: record.name)
            return WeaveThreadEntry(id: record.name, label: record.name, home: record.home, httpPort: record.threadHTTP,
                                    grpcPort: record.threadGRPC, status: status.label, woven: record.woven,
                                    embedder: snapshot.fabric.embedder[record.name]?.phase.rawValue,
                                    documents: snapshot.fabric.counts[record.name]?.documents, node: node, accepting: status.isUp)
        }
        return WeaveThreads(host: snapshot.hostInfo, ownerId: WeaveIdentity.owner, threads: entries + [main(snapshot)])
    }

    /// The main AII's Thread, as a push target (`main`): up when the host sees it.
    static func main(_ snapshot: PortOps.Snapshot, home: AIIHome = .resolved()) -> WeaveThreadEntry {
        let ports = AIIConfig.load(home: home).threadPorts
        let node = snapshot.host.nodes.first { $0.httpPort == ports.http }
        let up = node?.isActive ?? false
        return WeaveThreadEntry(id: ThreadGateway.mainName, label: "main AII", home: PrivateFile.path(home.root), httpPort: ports.http,
                                grpcPort: ports.grpc, status: node == nil ? "unknown" : (up ? "up" : "stopped"), woven: true,
                                embedder: nil, documents: nil,
                                node: node.map { WeaveThreadEntry.Node(threadId: $0.threadId, isActive: $0.isActive, acceptingStorage: $0.acceptingStorage) },
                                accepting: up)
    }

    public static func searchResponse(_ response: SewnSearchResponse, snapshot: Snapshot, mainThreadHTTP: Int?) -> WeaveSearchResponse {
        let hits = SearchOps.hits(response, nodes: snapshot.host.nodes, records: snapshot.fabric.threads, mainThreadHTTP: mainThreadHTTP)
        return WeaveSearchResponse(host: snapshot.hostInfo, texts: response.texts, references: response.references, hits: hits,
                                   graph: response.graph)
    }
}

/// The port's view of the services: snapshots read on main, the search sent to the host.
struct LiveGatewaySource: WeaveGatewaySource {
    let port: Int

    private func snapshot() async -> PortOps.Snapshot {
        let port = self.port
        return await MainActor.run {
            PortOps.Snapshot(port: port, host: Live.service(HostService.self).state, fabric: Live.service(FabricService.self).state)
        }
    }

    func health() async -> WeaveHealth { PortOps.health(await snapshot()) }

    func threads() async -> WeaveThreads { PortOps.threads(await snapshot()) }

    func search(_ request: WeaveSearchRequest) async throws -> WeaveSearchResponse {
        let snapshot = await snapshot()
        guard let target = snapshot.host.target, snapshot.host.sewn.isUp else { throw FabricError.noHost }
        let response = try await SewnHTTPClient.forTarget(target).search(request.query, topK: request.topK ?? 10)
        return PortOps.searchResponse(response, snapshot: snapshot, mainThreadHTTP: SearchOps.mainThreadHTTP())
    }

    func push(_ request: WeavePushRequest, thread: String) async throws -> WeavePushResponse {
        try await ThreadGateway.push(request, thread: thread, endpoint: endpoint(thread, await snapshot()))
    }

    func search(_ request: WeaveThreadSearchRequest, thread: String) async throws -> WeaveThreadSearchResponse {
        try await ThreadGateway.search(request, thread: thread, endpoint: endpoint(thread, await snapshot()))
    }

    func records(thread: String) async throws -> WeaveRecordsResponse {
        try await ThreadGateway.records(thread: thread, endpoint: endpoint(thread, await snapshot()))
    }

    private func endpoint(_ thread: String, _ snapshot: PortOps.Snapshot) throws -> ExplorerOps.Endpoint {
        try ExplorerOps.endpoint(ThreadGateway.ref(thread), records: snapshot.fabric.threads)
    }

    func secret() -> String? { try? AIIHome.resolved().readSecret(for: WeaveIdentity.app) }

    func served(_ path: String) async {
        let date = Date()
        await MainActor.run { Live.service(PortService.self).set(.served(path, date)) }
    }
}
