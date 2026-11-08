//
//  EndToEnd.swift
//  Weave
//
//  `Weave --e2e <folder>`: the whole fabric against this Mac's real AII (~/.rao and its installed
//  AIIServer), headless, through the same services the pages use:
//
//    1. spawn alpha (on-device graph) and beta (keywords) into <folder>, woven, host = main AII;
//    2. start both and wait for their embedders and their registration with the main Sewn;
//    3. deposit a distinct note into each, filed as local-weave;
//    4. one federated search through the main Sewn finds both partitions, named by instance,
//       and Weave's own port answers the same; Ambient's scope does not see Weave's nodes;
//    5. make alpha the host: its own Sewn comes up, both Threads move onto it, the search holds;
//    6. back to the main AII, then stop, remove, and let the lease go.
//
//  Exits 0 when every step held, 1 otherwise. Leaves nothing behind but Weave's registration in
//  ~/.rao (its secret and lane), which the app makes anyway.
//

import Foundation
import Granite
import WeaveKit

enum EndToEnd {
    @MainActor
    static func run(arguments: [String]) async -> Int32 {
        guard let index = arguments.firstIndex(of: "--e2e"), arguments.count > index + 1 else {
            print("usage: Weave --e2e <scratch folder on APFS>"); return 2
        }
        let root = URL(fileURLWithPath: arguments[index + 1], isDirectory: true).appendingPathComponent("fabric-\(UUID().uuidString.prefix(6))")
        var failures = 0
        func check(_ ok: Bool, _ line: String) {
            print(ok ? "  ✓ \(line)" : "  ✗ \(line)")
            if !ok { failures += 1 }
        }
        func step(_ title: String) { print("▸ \(title)") }

        let app = WeaveAppRoot.shared
        let fabric = app.fabric, host = app.host, search = app.search, port = app.port
        let main = AIIHome.resolved()
        let marker = UUID().uuidString.prefix(6).lowercased()
        let notes = [
            "alpha": "The loom in the alpha archive \(marker) is a Jacquard loom that reads punched cards to lift each warp thread.",
            "beta": "The beta ledger \(marker) records that a flying shuttle carries the weft across the shed in one throw.",
        ]

        do {
            step("fabric in \(root.path)")
            try await fabric.scan(root: root.path)
            check(true, "Weave registered in \(PrivateFile.path(main.root)) (fabric \(fabric.state.fabricFingerprint ?? "?"))")
            let target = try await host.select(.main, root: root.path)
            check(target.sewnPorts == AIIConfig.load(home: main).sewnPorts, "host = main AII, Sewn \(target.sewnPorts)")

            step("spawn and start")
            _ = try await fabric.spawn(name: "alpha", graphBackend: "mlx")
            _ = try await fabric.spawn(name: "beta", graphBackend: "keyword")
            for name in ["alpha", "beta"] {
                try await fabric.start(name, mothership: target.sewnPorts)
                let record = fabric.state.record(name)!
                check(fabric.state.status(of: name).isUp, "\(name) up on http \(record.threadHTTP) grpc \(record.threadGRPC)")
                check(fabric.state.shapes[name]?.mothershipGRPCPort == target.sewnPorts.grpc, "\(name) registers with \(target.sewnPorts.grpc)")
            }
            let ready = await poll(240) { await embeddersReady(fabric) }
            check(ready, "both embedders ready")

            let registered = await poll(90) {
                await host.poll()
                let ports = Set(host.state.nodes.filter(\.isActive).map(\.httpPort))
                return fabric.state.threads.allSatisfy { ports.contains($0.threadHTTP) }
            }
            check(registered, "the main Sewn sees both as nodes: \(host.state.nodes.map { "\($0.app ?? "?"):\($0.httpPort)" })")
            check(host.state.nodes.filter { fabric.state.threads.map(\.threadHTTP).contains($0.httpPort) }.allSatisfy { $0.app == "weave" },
                  "they registered as Weave's nodes")
            let ambientSees = (try? await AIIClient(app: .ambient, home: main).threads()) ?? []
            check(!ambientSees.contains { node in fabric.state.threads.contains { $0.threadHTTP == node.httpPort } },
                  "Ambient's scope does not see them (\(ambientSees.count) node(s) for Ambient)")

            step("deposit")
            for (name, text) in notes.sorted(by: { $0.key < $1.key }) {
                let record = fabric.state.record(name)!
                let receipt = try await ThreadHTTPClient.forHome(record.aiiHome, port: record.threadHTTP)
                    .deposit(text, name: "\(name)-note", groupID: "weave-\(name)", groupLabel: "Weave · \(name)")
                check(receipt.success, "filed a note into \(name)")
            }

            step("federated search through the main AII")
            var hits: [SearchHit] = []
            let found = await poll(90) {
                hits = (try? await search.query("loom shuttle weft warp \(marker)", topK: 10)) ?? []
                return Set(hits.filter { $0.text.contains(marker) }.compactMap(\.threadName)) == ["alpha", "beta"]
            }
            check(found, "one search found both partitions: \(hits.filter { $0.text.contains(marker) }.map { $0.threadName ?? "?" })")
            if !found, let error = search.state.lastError { print("    \(error)") }

            let testPort = 47698
            port.start(port: testPort, requireSecret: true)
            _ = await poll(10) { await MainActor.run { port.state.listening } }
            let secret = try main.readSecret(for: WeaveIdentity.app)
            let body = LoopbackHTTP.encode(WeaveSearchRequest(query: "loom shuttle \(marker)", topK: 10))
            let viaPort = try await LoopbackHTTP.json(WeaveSearchResponse.self,
                                                      LoopbackHTTP.request(port: testPort, path: "/v1/search", body: body, secret: secret, timeout: 90))
            check(Set(viaPort.hits.filter { $0.text.contains(marker) }.compactMap(\.threadName)) == ["alpha", "beta"],
                  "Weave's port answers the same, named by instance")
            port.stop()

            step("alpha as the host")
            let alphaTarget = try await host.select(.spawned("alpha"), root: root.path)
            check(host.state.sewn.isUp, "alpha's Sewn up on \(alphaTarget.sewnPorts)")
            check(Set(host.state.rewoven) == ["alpha", "beta"], "both Threads moved onto alpha: \(host.state.rewoven)")
            let moved = await poll(120) {
                await host.poll()
                let ports = Set(host.state.nodes.filter(\.isActive).map(\.httpPort))
                return fabric.state.threads.allSatisfy { ports.contains($0.threadHTTP) }
            }
            check(moved, "alpha's Sewn sees both: \(host.state.nodes.map { "\($0.app ?? "?"):\($0.httpPort)" })")
            _ = await poll(240) { await embeddersReady(fabric) }
            let foundOnAlpha = await poll(90) {
                hits = (try? await search.query("loom shuttle weft warp \(marker)", topK: 10)) ?? []
                return Set(hits.filter { $0.text.contains(marker) }.compactMap(\.threadName)) == ["alpha", "beta"]
            }
            check(foundOnAlpha, "the search through alpha finds both: \(hits.filter { $0.text.contains(marker) }.map { $0.threadName ?? "?" })")
            if !foundOnAlpha, let error = search.state.lastError { print("    \(error)") }
        } catch {
            check(false, "unexpected: \(FabricOps.message(error))")
        }

        step("clean up")
        _ = try? await host.select(.main, root: root.path)
        for name in fabric.state.threads.map(\.name) { try? await fabric.remove(name) }
        HostService.shutdownSync(stopSpawned: false, records: [])
        try? FileManager.default.removeItem(at: root)
        check(fabric.state.threads.isEmpty, "removed the spawned AIIs")
        print(failures == 0 ? "e2e passed" : "e2e failed (\(failures))")
        return failures == 0 ? 0 : 1
    }

    @MainActor
    private static func embeddersReady(_ fabric: FabricService) async -> Bool {
        await fabric.tick()
        await MainQueue.flush()
        return fabric.state.threads.allSatisfy { fabric.state.embedder[$0.name]?.phase == .ready }
    }

    /// Polls `condition` every second for up to `seconds`.
    @MainActor
    private static func poll(_ seconds: Int, _ condition: () async -> Bool) async -> Bool {
        for _ in 0..<seconds {
            if await condition() { return true }
            try? await TaskSleep.seconds(1)
        }
        return await condition()
    }
}
