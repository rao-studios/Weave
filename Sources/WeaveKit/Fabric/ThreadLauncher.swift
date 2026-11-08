//
//  ThreadLauncher.swift
//  WeaveKit
//
//  The launch specs of a spawned AII's two possible processes, built with AII's own LaunchSpecs so
//  the arguments, the environment allowlist, the run record and the log are AII's. Both run the
//  main home's installed AIIServer (Weave never builds one) and are launched by `ManagedServer`
//  with no signature policy, as Braid's demo AIIs are: the binary is the person's own build.
//

import Foundation

public enum ThreadLauncher {
    /// The installed server, `~/.rao/aii/bin/AIIServer`.
    public static func serverBinary(main: AIIHome = .resolved()) -> URL { main.serverBinary }

    /// `AIIServer thread` in the record's home, registered with `mothership` when given and woven.
    public static func threadSpec(_ record: ThreadRecord, mothership: AIIPorts?, executable: URL = serverBinary(),
                                  inherited: [String: String] = ProcessInfo.processInfo.environment) -> LaunchSpec {
        let home = record.aiiHome
        let registers = record.woven && mothership != nil
        let options = ThreadLaunchOptions(useMLX: true, graphBackend: record.graphBackend, mlxModel: AIIModels.embedding.id,
                                          graphModel: nil, ports: record.threadPorts, mothership: registers)
        return LaunchSpecs.thread(home: home, config: AIIConfig.load(home: home), executable: executable,
                                  sewnPorts: registers ? mothership : record.sewnPorts, options: options,
                                  challengeApp: WeaveIdentity.app, inherited: inherited)
    }

    /// `AIIServer sewn` in the record's home, on its slot's Sewn ports: the host when this AII is chosen.
    public static func sewnSpec(_ record: ThreadRecord, executable: URL = serverBinary(),
                                inherited: [String: String] = ProcessInfo.processInfo.environment) -> LaunchSpec {
        let home = record.aiiHome
        return LaunchSpecs.sewn(home: home, config: AIIConfig.load(home: home), executable: executable,
                                challengeApp: WeaveIdentity.app, inherited: inherited)
    }

    /// The managed process for `spec`, proved with Weave's secret in `home`.
    public static func server(_ spec: LaunchSpec, home: AIIHome) throws -> ManagedServer {
        guard let secret = try home.readSecret(for: WeaveIdentity.app) else { throw FabricError.noWeaveSecret }
        return ManagedServer(spec: spec, secret: secret, launcherApp: WeaveIdentity.app, policy: nil)
    }

    /// The config a spawned home is written with: its slot's ports and its graph backend.
    public static func config(for record: ThreadRecord) -> AIIConfig {
        AIIConfig(sewn: .init(httpPort: record.sewnHTTP, grpcPort: record.sewnGRPC),
                  thread: .init(httpPort: record.threadHTTP, grpcPort: record.threadGRPC, graphBackend: record.graphBackend))
    }
}
