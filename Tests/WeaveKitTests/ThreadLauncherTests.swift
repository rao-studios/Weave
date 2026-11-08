//
//  ThreadLauncherTests.swift
//  WeaveKitTests
//

import Foundation
import Testing
import WeaveKitTestSupport
@testable import WeaveKit

@Suite struct ThreadLauncherTests {
    let binary = URL(fileURLWithPath: "/tmp/AIIServer")

    @Test func aWovenThreadRegistersWithTheHostsSewn() {
        let record = Fixtures.record("alpha")
        let spec = ThreadLauncher.threadSpec(record, mothership: AIIPortPlan.sewn, executable: binary, inherited: [:])
        let args = spec.arguments
        #expect(args.first == "thread")
        #expect(args.contains("--mothership-grpc-port"))
        #expect(args[args.firstIndex(of: "--mothership-grpc-port")! + 1] == String(AIIPortPlan.sewn.grpc))
        #expect(args[args.firstIndex(of: "--port")! + 1] == String(record.threadHTTP))
        #expect(args.contains("--use-mlx") && args.contains("--graph-backend"))
        #expect(spec.executable == binary)
        #expect(spec.environment[AIIHome.environmentKey] == record.home)
        #expect(spec.environment["HF_HOME"] == record.aiiHome.huggingFaceHome.path)
    }

    @Test func aLooseThreadOrNoHostRunsStandalone() {
        let loose = ThreadLauncher.threadSpec(Fixtures.record("beta", woven: false), mothership: AIIPortPlan.sewn, executable: binary, inherited: [:])
        #expect(!loose.arguments.contains("--mothership-host"))
        let hostless = ThreadLauncher.threadSpec(Fixtures.record("gamma"), mothership: nil, executable: binary, inherited: [:])
        #expect(!hostless.arguments.contains("--mothership-host"))
    }

    @Test func aRunningThreadRestartsOnlyWhenItsMothershipDiffers() {
        let woven = Fixtures.record("alpha")
        let onMain = LaunchShape(mothershipGRPCPort: AIIPortPlan.sewn.grpc, graphBackend: "mlx", launchedAt: Date())
        #expect(!FabricOps.needsRestart(record: woven, shape: onMain, mothership: AIIPortPlan.sewn))
        #expect(FabricOps.needsRestart(record: woven, shape: onMain, mothership: woven.sewnPorts))
        #expect(FabricOps.needsRestart(record: woven, shape: nil, mothership: AIIPortPlan.sewn), "no sidecar: restart to be sure")
        let loose = Fixtures.record("beta", woven: false)
        #expect(!FabricOps.needsRestart(record: loose, shape: LaunchShape(mothershipGRPCPort: nil, graphBackend: "mlx", launchedAt: Date()),
                                        mothership: AIIPortPlan.sewn))
    }
}
