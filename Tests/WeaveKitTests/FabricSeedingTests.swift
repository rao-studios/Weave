//
//  FabricSeedingTests.swift
//  WeaveKitTests
//
//  The identity scheme on real AII homes in a scratch folder: AII's own provisioning, unmocked.
//

import Foundation
import Testing
import WeaveKitTestSupport
@testable import WeaveKit

@Suite struct FabricSeedingTests {
    @Test func aSpawnedHomeSharesTheFabricSecretTheDeviceKeyAndWeavesLane() throws {
        let scratch = Scratch(); defer { scratch.clean() }
        let fabric = try FabricSeeding.prepareMain(scratch.main)
        #expect(StackSecret.isWellFormedSecret(fabric))
        #expect(scratch.main.lane(WeaveIdentity.app)?.owner.rawValue == WeaveIdentity.owner)

        let home = AIIHome(root: scratch.root.appendingPathComponent("alpha", isDirectory: true))
        try FabricSeeding.provision(home: home, main: scratch.main, fabric: fabric)

        #expect(try home.readSecret(for: .stack) == fabric)
        #expect(try home.readSecret(for: WeaveIdentity.app) != fabric, "the home's own Weave secret is distinct")
        #expect(FileManager.default.contents(atPath: home.deviceKeyFile.path) == FileManager.default.contents(atPath: scratch.main.deviceKeyFile.path))
        #expect(home.lane(WeaveIdentity.app)?.id == scratch.main.lane(WeaveIdentity.app)?.id)
        #expect(home.lane(.ambient)?.id == scratch.main.lane(.ambient)?.id)
    }

    @Test func provisioningTwiceChangesNothing() throws {
        let scratch = Scratch(); defer { scratch.clean() }
        let fabric = try FabricSeeding.prepareMain(scratch.main)
        let home = AIIHome(root: scratch.root.appendingPathComponent("beta", isDirectory: true))
        try FabricSeeding.provision(home: home, main: scratch.main, fabric: fabric)
        let first = try home.readSecret(for: WeaveIdentity.app)
        try FabricSeeding.provision(home: home, main: scratch.main, fabric: fabric)
        #expect(try home.readSecret(for: WeaveIdentity.app) == first)
        #expect(try FabricSeeding.prepareMain(scratch.main) == fabric)
    }

    @Test func aRotatedFabricSecretIsCaughtAndReseeded() throws {
        let scratch = Scratch(); defer { scratch.clean() }
        let fabric = try FabricSeeding.prepareMain(scratch.main)
        let home = AIIHome(root: scratch.root.appendingPathComponent("gamma", isDirectory: true))
        try FabricSeeding.provision(home: home, main: scratch.main, fabric: fabric)
        let rotated = StackSecret.generate()
        #expect(!FabricSeeding.verify(home: home, fabric: rotated))
        try FabricSeeding.reseed(home: home, fabric: rotated)
        #expect(FabricSeeding.verify(home: home, fabric: rotated))
    }

    @Test func theRootLinksTheMainModelsAndEachHomeLinksTheRoot() throws {
        let scratch = Scratch(); defer { scratch.clean() }
        try FileManager.default.createDirectory(at: scratch.main.huggingFaceHome, withIntermediateDirectories: true)
        let fabric = try FabricSeeding.prepareMain(scratch.main)
        let file = try FabricRoot.ensure(root: scratch.root, main: scratch.main)
        #expect(file.host == .main)
        let shared = FabricRoot.sharedModels(root: scratch.root)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: shared.path) == scratch.main.huggingFaceHome.path)

        let home = AIIHome(root: scratch.root.appendingPathComponent("delta", isDirectory: true))
        try FabricSeeding.provision(home: home, main: scratch.main, fabric: fabric)
        try FabricSeeding.shareModels(home: home, root: scratch.root)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: home.huggingFaceHome.path) == shared.path)
    }

    @Test func aSpawnWritesTheRecordAndTheConfigOnAFreeSlot() throws {
        let scratch = Scratch(); defer { scratch.clean() }
        try FabricSeeding.prepareMain(scratch.main)
        try FabricRoot.ensure(root: scratch.root, main: scratch.main)
        var state = FabricService.Center.State()
        state.root = scratch.root.path
        let record = try FabricOps.spawn(name: "alpha", graphBackend: "keyword", woven: true, softCap: 8, state: state,
                                         main: scratch.main, listening: { _ in false })
        #expect(record.threadPorts == AIIPorts(http: 47611, grpc: 47612))
        #expect(ThreadRecord.load(home: URL(fileURLWithPath: record.home)) == record)
        let config = AIIConfig.load(home: record.aiiHome)
        #expect(config.threadPorts == record.threadPorts && config.sewnPorts == record.sewnPorts)
        #expect(config.thread.graphBackend == "keyword")
        #expect(FabricRoot.records(root: scratch.root).map(\.name) == ["alpha"])

        state.threads = [record]
        #expect(throws: FabricError.exists("alpha")) {
            try FabricOps.spawn(name: "alpha", graphBackend: "mlx", woven: true, softCap: 8, state: state, main: scratch.main, listening: { _ in false })
        }
        #expect(throws: FabricError.invalidName("Bad-Name")) {
            try FabricOps.spawn(name: "Bad-Name", graphBackend: "mlx", woven: true, softCap: 8, state: state, main: scratch.main, listening: { _ in false })
        }
        #expect(throws: FabricError.softCap(1)) {
            try FabricOps.spawn(name: "beta", graphBackend: "mlx", woven: true, softCap: 1, state: state, main: scratch.main, listening: { _ in false })
        }
    }
}
