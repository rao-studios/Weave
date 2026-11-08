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

    /// The AII id of each Thread the host fans out to, for a search across every AII.
    public static func names(_ snapshot: Snapshot, mainThreadHTTP: Int?) -> [String: String] {
        var names: [String: String] = [:]
        for node in snapshot.host.nodes {
            if let record = snapshot.fabric.threads.first(where: { $0.threadHTTP == node.httpPort }) { names[node.threadId] = record.name }
            else if node.httpPort == mainThreadHTTP { names[node.threadId] = ThreadGateway.mainName }
        }
        return names
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

    func route(aii: String) async throws -> ForwardTarget {
        let snapshot = await snapshot()
        let endpoint = try ExplorerOps.endpoint(ThreadGateway.ref(aii), records: snapshot.fabric.threads)
        guard let secret = try endpoint.home.readSecret(for: WeaveIdentity.app) else { throw FabricError.noWeaveSecret }
        return ForwardTarget(aii: aii, port: endpoint.threadHTTP, secret: secret)
    }

    func host() async throws -> (target: ForwardTarget, names: [String: String]) {
        let snapshot = await snapshot()
        guard let target = snapshot.host.target, snapshot.host.sewn.isUp, let secret = target.secret() else { throw FabricError.noHost }
        return (ForwardTarget(aii: nil, port: target.sewnPorts.http, secret: secret),
                PortOps.names(snapshot, mainThreadHTTP: SearchOps.mainThreadHTTP()))
    }

    func secret() -> String? { try? AIIHome.resolved().readSecret(for: WeaveIdentity.app) }

    func served(_ path: String) async {
        let date = Date()
        await MainActor.run { Live.service(PortService.self).set(.served(path, date)) }
    }
}
