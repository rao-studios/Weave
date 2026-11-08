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

    @Test func weaveLeavesASecretAndALaneInTheMainHomeAndNoFolder() throws {
        let scratch = Scratch(); defer { scratch.clean() }
        try FabricSeeding.prepareMain(scratch.main)
        #expect(try scratch.main.readSecret(for: WeaveIdentity.app) != nil)
        #expect(scratch.main.lane(WeaveIdentity.app) != nil)
        #expect(!FileManager.default.fileExists(atPath: scratch.main.appDirectory(WeaveIdentity.app).path))
        #expect(!FileManager.default.fileExists(atPath: scratch.main.root.appendingPathComponent("weave").path))

        try FabricSeeding.unregister(scratch.main)
        #expect(try scratch.main.readSecret(for: WeaveIdentity.app) == nil)
        #expect(scratch.main.lane(WeaveIdentity.app) == nil)
    }

    @Test func withoutAMainAIIWeaveRefusesToMakeOne() {
        let scratch = Scratch(installed: false); defer { scratch.clean() }
        #expect(throws: FabricError.noMainAII(PrivateFile.path(scratch.main.root))) { try FabricSeeding.prepareMain(scratch.main) }
        #expect(!FileManager.default.fileExists(atPath: scratch.main.layoutFile.path))
    }

    @Test func anEmptyLegacyFabricInRaoIsSweptAndOneWithAIIsIsKept() throws {
        let scratch = Scratch(); defer { scratch.clean() }
        let fabric = try FabricSeeding.prepareMain(scratch.main)
        let legacy = scratch.main.root.appendingPathComponent("weave", isDirectory: true)
        try FabricRoot.ensure(root: legacy, main: scratch.main)
        try FileManager.default.createDirectory(at: scratch.main.appDirectory(WeaveIdentity.app), withIntermediateDirectories: true)
        #expect(FabricRoot.sweepLegacy(main: scratch.main) == nil)
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
        #expect(!FileManager.default.fileExists(atPath: scratch.main.appDirectory(WeaveIdentity.app).path))

        try FabricRoot.ensure(root: legacy, main: scratch.main)
        let home = AIIHome(root: legacy.appendingPathComponent("old", isDirectory: true))
        try FabricSeeding.provision(home: home, main: scratch.main, fabric: fabric)
        try Fixtures.record("old", home: home.root.path).write()
        #expect(FabricRoot.sweepLegacy(main: scratch.main)?.contains(legacy.path) == true)
        #expect(FileManager.default.fileExists(atPath: legacy.path))
    }

    @Test func theDefaultFabricIsWeavesOwnFolderAndItsSizeSkipsTheModelsLink() throws {
        #expect(FabricRoot.url(FabricRoot.defaultPath).path.hasPrefix(WeaveIdentity.supportDirectory.path))
        #expect(!FabricRoot.defaultPath.contains(".rao"))
        let scratch = Scratch(); defer { scratch.clean() }
        try FileManager.default.createDirectory(at: scratch.main.huggingFaceHome, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 2_000_000).write(to: scratch.main.huggingFaceHome.appendingPathComponent("weights.bin"))
        try FabricSeeding.prepareMain(scratch.main)
        try FabricRoot.ensure(root: scratch.root, main: scratch.main)
        #expect(FabricRoot.diskUsage(root: scratch.root) < 1_000_000, "the shared models are ~/.rao's, not the fabric's")
    }

    @Test func aCustomLocationMustAlreadyBeThereAndHoldHardLinks() throws {
        let scratch = Scratch(); defer { scratch.clean() }
        let missing = scratch.url.appendingPathComponent("unplugged/rao/weave", isDirectory: true)
        #expect(throws: FabricError.unavailable(missing.path)) { try FabricRoot.usable(missing, mustExist: true) }
        #expect(!FileManager.default.fileExists(atPath: missing.path), "nothing is made in its place")
        try FabricRoot.usable(missing)
        try FileManager.default.createDirectory(at: missing, withIntermediateDirectories: true)
        try FabricRoot.usable(missing, mustExist: true)
        let exfat = FabricError.noHardLinks("/Volumes/T9/rao/weave", format: "ExFAT").errorDescription ?? ""
        #expect(exfat.contains("is on an ExFAT volume") && exfat.contains("APFS"))
    }

    @Test func removingAFabricFromAFolderLeavesWhatWeaveDidNotMake() throws {
        let scratch = Scratch(); defer { scratch.clean() }
        let fabric = try FabricSeeding.prepareMain(scratch.main)
        try FabricRoot.ensure(root: scratch.root, main: scratch.main)
        let home = AIIHome(root: scratch.root.appendingPathComponent("alpha", isDirectory: true))
        try FabricSeeding.provision(home: home, main: scratch.main, fabric: fabric)
        try Fixtures.record("alpha", home: home.root.path).write()
        let mine = scratch.root.appendingPathComponent("notes.txt")
        try Data("mine".utf8).write(to: mine)
        FabricRoot.removeFabric(root: scratch.root)
        #expect(!FileManager.default.fileExists(atPath: home.root.path))
        #expect(!FileManager.default.fileExists(atPath: scratch.root.appendingPathComponent(FabricFile.fileName).path))
        #expect(FileManager.default.fileExists(atPath: mine.path), "a custom folder's other files stay")
        try FileManager.default.removeItem(at: mine)
        try FabricRoot.ensure(root: scratch.root, main: scratch.main)
        FabricRoot.removeFabric(root: scratch.root)
        #expect(!FileManager.default.fileExists(atPath: scratch.root.path), "an emptied folder goes")
    }
}
