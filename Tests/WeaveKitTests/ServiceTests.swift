//
//  ServiceTests.swift
//  WeaveKitTests
//
//  The services through their ticketed entries, on a scratch AII home (AII_HOME) and a scratch
//  fabric folder. Relays are process singletons, so every suite that boots a service nests under
//  one serialized parent.
//

import Foundation
import Granite
import Testing
import WeaveKitTestSupport
@testable import WeaveKit

@MainActor final class TestRoot {
    static let shared: TestRoot = {
        GraniteLogger.currentLevel = .error
        return TestRoot()
    }()
    @Relay(.silence) var fabric: FabricService
    @Relay(.silence) var host: HostService
    @Relay(.silence) var search: SearchService
    @Relay(.silence) var explorer: ExplorerService
    @Relay(.silence) var port: PortService

    /// A fresh scratch home and fabric; the services cleared.
    func boot() -> Scratch {
        let scratch = Scratch("weave-service-tests")
        setenv(AIIHome.environmentKey, scratch.main.root.path, 1)
        fabric.set(.clear); host.set(.clear); search.set(.clear); explorer.set(.clearAll)
        return scratch
    }
}

@Suite(.serialized) @MainActor struct ServicesOnScratch {}

extension ServicesOnScratch {
    @Suite @MainActor struct FabricServiceTests {
        @Test func scanSpawnAndRemoveWriteThroughTheService() async throws {
            let root = TestRoot.shared
            let scratch = root.boot(); defer { scratch.clean() }
            let scan = try await root.fabric.scan(root: scratch.root.path)
            #expect(scan.records.isEmpty)
            await Task.yield()
            #expect(root.fabric.state.scanned && root.fabric.state.fabricFingerprint == scan.fingerprint)

            let record = try await root.fabric.spawn(name: "alpha", graphBackend: "keyword")
            await Task.yield()
            #expect(root.fabric.state.threads.map(\.name) == ["alpha"])
            #expect(root.fabric.state.busy.isEmpty, "the spawn freed its instance")
            #expect(root.fabric.state.status(of: "alpha") == .stopped(nil))

            await #expect(throws: FabricError.exists("alpha")) { try await root.fabric.spawn(name: "alpha", graphBackend: "mlx") }

            try await root.fabric.remove("alpha")
            await Task.yield()
            #expect(root.fabric.state.threads.isEmpty)
            #expect(!FileManager.default.fileExists(atPath: record.home))
        }

        @Test func anAIIIsLabelledAtSpawnBackfilledAtAScanAndRelabelledInItsHome() async throws {
            let root = TestRoot.shared
            let scratch = root.boot(); defer { scratch.clean() }
            try await root.fabric.scan(root: scratch.root.path)
            let alpha = try await root.fabric.spawn(name: "alpha", graphBackend: "keyword")
            #expect(AIILabel.read(home: alpha.aiiHome) == "alpha", "named as it was spawned")

            // An AII with a label of its own keeps it; one with none is given its name.
            let beta = try await root.fabric.spawn(name: "beta", graphBackend: "keyword")
            AIILabel.clear(home: beta.aiiHome)
            try AIILabel.write("Apple Reasoning", home: alpha.aiiHome)
            let scan = try await root.fabric.scan(root: scratch.root.path)
            #expect(scan.labels == ["alpha": "Apple Reasoning", "beta": "beta"])
            #expect(AIILabel.read(home: alpha.aiiHome) == "Apple Reasoning", "the AII's label is never changed by a scan")
            #expect(AIILabel.read(home: beta.aiiHome) == "beta")
            await Task.yield()
            #expect(root.fabric.state.title(of: "alpha") == "Apple Reasoning")

            try await root.fabric.label("beta", as: "  Beta Notes ")
            await Task.yield()
            #expect(AIILabel.read(home: beta.aiiHome) == "Beta Notes")
            #expect(root.fabric.state.title(of: "beta") == "Beta Notes")
            #expect(root.fabric.state.busy.isEmpty)
            await #expect(throws: AIILabelError.invalid("a\nb")) { try await root.fabric.label("beta", as: "a\nb") }
            #expect(root.fabric.state.record("beta") != nil, "the handle stays")
        }

        @Test func startingWithoutAnInstalledServerSaysSo() async throws {
            let root = TestRoot.shared
            let scratch = root.boot(); defer { scratch.clean() }
            try await root.fabric.scan(root: scratch.root.path)
            _ = try await root.fabric.spawn(name: "beta", graphBackend: "keyword")
            let binary = ThreadLauncher.serverBinary().path
            await #expect(throws: FabricError.noServer(binary)) { try await root.fabric.start("beta", mothership: nil) }
            await Task.yield()
            #expect(root.fabric.state.busy.isEmpty)
            #expect(root.fabric.state.lastError?.contains("beta") == true)
        }
    }

    @Suite @MainActor struct SearchServiceTests {
        @Test func aQueryWithNoHostFailsAndSaysSo() async throws {
            let root = TestRoot.shared
            let scratch = root.boot(); defer { scratch.clean() }
            await #expect(throws: FabricError.noHost) { try await root.search.query("loom") }
            await Task.yield()
            #expect(root.search.state.lastError?.contains("No host") == true)
            #expect(!root.search.state.searching)
        }
    }

    @Suite @MainActor struct ExplorerServiceTests {
        @Test func aReadOfAMissingThreadLandsAsThatPanesError() async throws {
            let root = TestRoot.shared
            let scratch = root.boot(); defer { scratch.clean() }
            root.explorer.select(.spawned("ghost"))
            await Task.yield()
            let ok = await root.explorer.load(.stats, on: .spawned("ghost"))
            await Task.yield()
            #expect(!ok)
            #expect(root.explorer.state.errors[.stats] != nil)
            #expect(!root.explorer.state.isLoading(.stats))
        }
    }
}
