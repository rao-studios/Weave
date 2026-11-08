//
//  SelfTest.swift
//  Weave
//
//  `Weave --self-test`: the app's services driven the way the pages drive them, headless, against
//  a scratch AII home (AII_HOME, so ~/.rao is never touched) and a scratch fabric folder: Weave
//  registers in the home, the folder is scanned, an AII is spawned and provisioned (its seed and
//  lanes checked), Weave's port is opened and asked /health and /v1/threads, and everything is
//  removed. Needs no AIIServer. Exits 0 when every step held, 1 otherwise.
//

import Foundation
import Granite
import WeaveKit

enum SelfTest {
    @MainActor
    static func run(arguments: [String]) async -> Int32 {
        let scratch = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("weave-self-test-\(UUID().uuidString.prefix(8))", isDirectory: true)
        let home = scratch.appendingPathComponent("rao", isDirectory: true)
        let root = scratch.appendingPathComponent("fabric", isDirectory: true)
        setenv(AIIHome.environmentKey, home.path, 1)
        defer { try? FileManager.default.removeItem(at: scratch) }

        var failures = 0
        func check(_ ok: Bool, _ line: String) {
            print(ok ? "  ✓ \(line)" : "  ✗ \(line)")
            if !ok { failures += 1 }
        }

        print("Weave self-test in \(scratch.path)")
        let app = WeaveAppRoot.shared
        await app.awaitSettingsLoaded()
        let fabric = app.fabric, port = app.port

        do {
            let scan = try await fabric.scan(root: root.path)
            check(scan.records.isEmpty, "scanned an empty fabric (\(scan.fingerprint))")
            let main = AIIHome(root: home)
            check((try? main.readSecret(for: WeaveIdentity.app)) != nil, "Weave registered in the scratch home")

            let record = try await fabric.spawn(name: "alpha", graphBackend: "keyword")
            check(record.threadHTTP == WeavePortPlan.slot(1).threadHTTP || record.threadHTTP > WeavePortPlan.base, "spawned alpha on \(record.threadHTTP)/\(record.threadGRPC)")
            let spawned = record.aiiHome
            check(FabricSeeding.verify(home: spawned, fabric: try main.readSecret(for: WeaveIdentity.app) ?? ""), "alpha's stack secret is the fabric's")
            check(spawned.lane(WeaveIdentity.app)?.id == main.lane(WeaveIdentity.app)?.id, "alpha's Weave lane is the main home's")
            check(AIIConfig.load(home: spawned).threadPorts == record.threadPorts, "alpha's config carries its slot")
            try? await Task.sleep(nanoseconds: 50_000_000)
            check(fabric.state.threads.map(\.name) == ["alpha"], "the fabric lists alpha")

            let testPort = 47699
            port.start(port: testPort, requireSecret: true)
            for _ in 0..<50 where !port.state.listening { try? await TaskSleep.seconds(0.1) }
            check(port.state.listening, "Weave's port listens on \(testPort)")
            let (health, healthStatus) = try await LoopbackHTTP.send(LoopbackHTTP.request(port: testPort, path: "/health", method: "GET", secret: nil))
            check(healthStatus == 200 && String(decoding: health, as: UTF8.self).contains("\"weave\""), "GET /health answers")
            let (_, refused) = try await LoopbackHTTP.send(LoopbackHTTP.request(port: testPort, path: "/v1/threads", method: "GET", secret: nil))
            check(refused == 401, "GET /v1/threads without the secret is refused")
            let secret = try main.readSecret(for: WeaveIdentity.app)
            let threads = try await LoopbackHTTP.json(WeaveThreads.self, LoopbackHTTP.request(port: testPort, path: "/v1/threads", method: "GET", secret: secret))
            check(threads.threads.map(\.name) == ["alpha"] && threads.ownerId == WeaveIdentity.owner, "GET /v1/threads lists alpha")
            port.stop()

            try await fabric.remove("alpha")
            check(!FileManager.default.fileExists(atPath: record.home), "removed alpha's home")
        } catch {
            check(false, "unexpected: \(FabricOps.message(error))")
        }
        print(failures == 0 ? "self-test passed" : "self-test failed (\(failures))")
        return failures == 0 ? 0 : 1
    }
}
