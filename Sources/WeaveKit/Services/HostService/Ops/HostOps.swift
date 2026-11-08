//
//  HostOps.swift
//  WeaveKit
//
//  HostService's bodies: the transitions, where a host listens, bringing its Sewn up and letting
//  it go, and reading what it sees.
//

import Foundation

public enum HostOps {
    public typealias State = HostService.Center.State

    public static func apply(_ kind: HostService.Set.Meta.Kind, to state: inout State) {
        switch kind {
        case .selected(let selection, let target):
            state.selection = selection
            state.target = target
            state.nodes = []
        case .sewn(let status):
            state.sewn = status
        case .mainPhase(let phase):
            state.mainPhase = phase
        case .nodes(let nodes, let date):
            state.nodes = nodes.sorted { ($0.httpPort, $0.threadId) < ($1.httpPort, $1.threadId) }
            state.lastPolled = date
        case .rewoven(let names):
            state.rewoven = names
        case .switched:
            state.switching = nil
        case .polling(let on, let interval):
            state.polling = on
            state.pollInterval = max(1, interval)
        case .failed(let message):
            state.lastError = message
        case .clear:
            state = State()
        }
    }

    /// Where `selection`'s Sewn listens.
    public static func resolve(_ selection: HostSelection, fabric: FabricService.Center.State,
                               main: AIIHome = .resolved()) throws -> HostTarget {
        switch selection {
        case .main:
            let config = AIIConfig.load(home: main)
            return HostTarget(selection: .main, homeRoot: PrivateFile.path(main.root), sewnPorts: config.sewnPorts,
                              threadPorts: config.threadPorts)
        case .spawned(let name):
            guard let record = fabric.record(name) else { throw FabricError.notFound(name) }
            return HostTarget(selection: selection, homeRoot: record.home, sewnPorts: record.sewnPorts, threadPorts: record.threadPorts)
        }
    }

    /// Brings `selection`'s Sewn up, or adopts it.
    static func bringUp(_ selection: HostSelection, fabric: FabricService.Center.State) async throws {
        switch selection {
        case .main:
            let supervisor = HostService.supervisors.get("main")
                ?? AIISupervisor(app: WeaveIdentity.app, home: .resolved(), hold: .lease)
            // Not `prepare()`: it provisions the home and makes apps/weave. Weave is registered by
            // FabricSeeding.prepareMain at every scan; the supervisor only holds the lease.
            _ = try FabricSeeding.prepareMain()
            try await supervisor.ensureRunning(timeout: 90)
            HostService.supervisors.put("main", supervisor)
        case .spawned(let name):
            guard let record = fabric.record(name) else { throw FabricError.notFound(name) }
            let binary = ThreadLauncher.serverBinary()
            guard FileManager.default.isExecutableFile(atPath: binary.path) else { throw FabricError.noServer(binary.path) }
            let server = try HostService.servers.get(name) ?? ThreadLauncher.server(ThreadLauncher.sewnSpec(record, executable: binary),
                                                                                     home: record.aiiHome)
            _ = try await server.ensureRunning(timeout: 90)
            HostService.servers.put(name, server)
        }
    }

    /// Lets the previous host go: the main AII's lease, or the Sewn Weave started in a spawned home.
    static func release(_ selection: HostSelection) async {
        switch selection {
        case .main:
            await HostService.supervisors.remove("main")?.release()
        case .spawned(let name):
            await HostService.servers.remove(name)?.stop(grace: 3)
        }
    }

    static func save(_ selection: HostSelection, root: String) {
        let url = FabricRoot.url(root)
        guard var file = FabricRoot.load(root: url) else { return }
        file.host = selection
        try? FabricRoot.save(file, root: url)
    }

    /// The host's health and nodes, written through `set`.
    static func poll(_ host: HostService) async {
        guard let target = await MainActor.run(body: { host.state.target }) else { return }
        let home = target.home
        let client = AIIClient(app: WeaveIdentity.app, home: home, config: AIIConfig.load(home: home))
        let health = await client.health()
        switch health.sewn {
        case .ours: host.set(.sewn(.up))
        case .down: host.set(.sewn(.down("no answer on \(target.sewnPorts.http)")))
        case .stale: host.set(.sewn(.down("port \(target.sewnPorts.http) answers, but not as this AII")))
        case .open: host.set(.sewn(.down("an open Sewn holds port \(target.sewnPorts.http)")))
        }
        if case .main = target.selection, let supervisor = HostService.supervisors.get("main") {
            host.set(.mainPhase(phaseLine(await supervisor.snapshot().phase)))
        }
        if health.sewn.isOurs, let nodes = try? await client.threads() {
            host.set(.nodes(nodes.map(HostNode.init), Date()))
        }
    }

    /// The main AII's phase in a few words.
    public static func phaseLine(_ phase: AIIStatus.Phase) -> String {
        switch phase {
        case .notInstalled(let detail): return "not installed" + (detail.map { ": \($0)" } ?? "")
        case .installing(let step): return "installing: \(step)"
        case .starting: return "starting"
        case .up: return "up"
        case .degraded(let detail): return "degraded: \(detail)"
        case .down(let detail): return "down" + (detail.map { ": \($0)" } ?? "")
        }
    }

    /// The Weave name for a node the host sees: the spawned AII whose Thread listens on its HTTP
    /// port, "main AII" for the main AII's Thread.
    public static func name(of node: HostNode, records: [ThreadRecord], mainThreadHTTP: Int?) -> String? {
        if let record = records.first(where: { $0.threadHTTP == node.httpPort }) { return record.name }
        if let mainThreadHTTP, node.httpPort == mainThreadHTTP { return "main AII" }
        return nil
    }
}
