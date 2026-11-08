//
//  FabricOps.swift
//  WeaveKit
//
//  FabricService's bodies: `apply` (every state transition, pure), and the work its reducers
//  dispatch, in values: scan the folder, probe a Thread, spawn a home, start and stop a Thread.
//

import Foundation

public enum FabricOps {
    public typealias State = FabricService.Center.State

    // MARK: - Transitions

    public static func apply(_ kind: FabricService.Set.Meta.Kind, to state: inout State) {
        switch kind {
        case .scanning(let on):
            state.scanning = on
        case .scanned(let scan):
            state.scanning = false
            state.scanned = true
            state.root = scan.root
            state.fabricFingerprint = scan.fingerprint
            state.serverBinary = scan.serverBinary
            state.serverInstalled = scan.serverInstalled
            state.threads = scan.records.sorted { $0.name < $1.name }
            state.shapes = scan.shapes
            state.reseed = scan.reseed
            let names = Swift.Set(scan.records.map(\.name))
            state.status = state.status.filter { names.contains($0.key) }
            state.embedder = state.embedder.filter { names.contains($0.key) }
            state.extractor = state.extractor.filter { names.contains($0.key) }
            state.counts = state.counts.filter { names.contains($0.key) }
            state.legacyNote = scan.legacyNote
            state.lastError = nil
        case .record(let record):
            if let index = state.threads.firstIndex(where: { $0.name == record.name }) { state.threads[index] = record }
            else { state.threads.append(record); state.threads.sort { $0.name < $1.name } }
        case .removed(let name):
            state.threads.removeAll { $0.name == name }
            state.status[name] = nil
            state.embedder[name] = nil
            state.extractor[name] = nil
            state.counts[name] = nil
            state.shapes[name] = nil
            state.reseed.remove(name)
        case .probe(let name, let probe):
            // A busy instance is mid-verb: its verb writes its status, a stale probe does not.
            if state.busy[name] == nil { state.status[name] = probe.status }
            state.embedder[name] = probe.embedder
            state.extractor[name] = probe.extractor
            if let counts = probe.counts { state.counts[name] = counts }
        case .status(let name, let status):
            state.status[name] = status
        case .shape(let name, let shape):
            state.shapes[name] = shape
        case .reseeded(let name):
            state.reseed.remove(name)
        case .idle(let name):
            state.busy[name] = nil
        case .loop(let on, let interval):
            state.loopRunning = on
            state.interval = max(1, interval)
        case .ticked(let date):
            state.lastTick = date
        case .disk(let bytes, let date):
            state.diskBytes = bytes
            state.measuredAt = date
        case .failed(let message):
            state.lastError = message
        case .clear:
            state = State()
        }
    }

    /// Adopts `ticket` as `name`'s request when the instance is idle (a verb's `reduce`).
    static func adopt(_ ticket: UUID, for name: String, in state: inout State) {
        if state.busy[name] == nil { state.busy[name] = ticket }
    }

    // MARK: - Scan

    public static func scan(root path: String, main: AIIHome = .resolved()) throws -> FabricScan {
        let fabric = try FabricSeeding.prepareMain(main)
        let legacyNote = FabricRoot.sweepLegacy(main: main)
        let root = FabricRoot.url(path)
        try FabricRoot.ensure(root: root, main: main)
        let records = FabricRoot.records(root: root)
        var shapes: [String: LaunchShape] = [:]
        var reseed: Swift.Set<String> = []
        for record in records {
            shapes[record.name] = LaunchShape.load(home: record.aiiHome)
            if !FabricSeeding.verify(home: record.aiiHome, fabric: fabric) { reseed.insert(record.name) }
        }
        let binary = ThreadLauncher.serverBinary(main: main)
        return FabricScan(root: root.path, fingerprint: FabricSeeding.fingerprint(fabric), records: records, shapes: shapes,
                          reseed: reseed, serverBinary: binary.path,
                          serverInstalled: FileManager.default.isExecutableFile(atPath: binary.path), legacyNote: legacyNote)
    }

    // MARK: - Probe

    /// One Thread now: its run record, its /health proved with Weave's secret, and its counts.
    public static func probe(_ record: ThreadRecord) async -> ThreadProbe {
        let home = record.aiiHome
        let run = RunRecord.load(home.threadRunRecord)
        let alive = run.map { ProcessProbe.isRunning($0.process) } ?? false
        let health = await ThreadHealth.probe(home: home, port: record.threadHTTP)
        let status: ThreadStatus
        switch health.verdict {
        case .ours:
            status = .up(pid: run?.process.pid ?? 0)
        case .down:
            status = alive ? .starting : .stopped(nil)
        case .stale:
            status = .unhealthy("port \(record.threadHTTP) answers, but not as this AII")
        case .open:
            status = .unhealthy("an open Thread holds port \(record.threadHTTP)")
        }
        var counts: ThreadCounts?
        if status.isUp, let client = try? ThreadHTTPClient.forHome(home, port: record.threadHTTP) {
            counts = (try? await client.stats()).map(ThreadCounts.init)
        }
        return ThreadProbe(status: status, embedder: health.embedder, extractor: health.extractor, counts: counts)
    }

    /// One probe of every idle Thread, written through `set`.
    static func tick(_ fabric: FabricService) async {
        let state = await MainActor.run { fabric.state }
        for record in state.threads where !state.isBusy(record.name) {
            fabric.set(.probe(record.name, await probe(record)))
        }
        fabric.set(.ticked(Date()))
        if !state.root.isEmpty, (state.measuredAt.map { Date().timeIntervalSince($0) > 60 } ?? true) {
            await measure(fabric, root: state.root)
        }
    }

    /// The fabric's size on disk, measured off main and written through `set`.
    static func measure(_ fabric: FabricService, root: String) async {
        let url = FabricRoot.url(root)
        let bytes = await Task.detached(priority: .utility) { FabricRoot.diskUsage(root: url) }.value
        fabric.set(.disk(bytes, Date()))
    }

    // MARK: - Spawn

    /// A new AII in the fabric. On a volume that cannot hard-link (an ExFAT drive), its folder
    /// there holds the record and the data, and its home is kept in `kept` on this Mac.
    public static func spawn(name: String, graphBackend: String, woven: Bool, softCap: Int, state: State,
                             main: AIIHome = .resolved(), listening: (Int) -> Bool = WeavePortPlan.isListening,
                             kept: URL = FabricRoot.keptHomes, hardLinks: (URL) -> Bool = FabricRoot.supportsHardLinks) throws -> ThreadRecord {
        guard ThreadRecord.isValidName(name), name != ThreadGateway.mainName else { throw FabricError.invalidName(name) }
        guard state.record(name) == nil else { throw FabricError.exists(name) }
        guard state.threads.count < max(1, softCap) else { throw FabricError.softCap(softCap) }
        let root = FabricRoot.url(state.root.isEmpty ? FabricRoot.defaultPath : state.root)
        let homeURL = root.appendingPathComponent(name, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: ThreadRecord.url(in: homeURL).path) else { throw FabricError.exists(name) }
        guard let slot = WeavePortPlan.freeSlot(taken: state.takenPorts, listening: listening) else { throw FabricError.noFreeSlot }
        guard let fabric = try main.readSecret(for: WeaveIdentity.app) else { throw FabricError.noWeaveSecret }

        let apart = !hardLinks(root)
        let home: AIIHome
        if apart {
            try PrivateFile.ensureDirectory(homeURL)
            try FileManager.default.createDirectory(at: kept, withIntermediateDirectories: true)
            try PrivateFile.ensureDirectory(kept)
            home = AIIHome(root: kept.appendingPathComponent("\(name)-\(UUID().uuidString.prefix(8).lowercased())", isDirectory: true))
        } else {
            home = AIIHome(root: homeURL)
        }
        try FabricSeeding.provision(home: home, main: main, fabric: fabric)
        try FabricSeeding.shareModels(home: home, root: root)
        let record = ThreadRecord(name: name, home: homeURL.path, createdAt: Date(), slot: slot,
                                  graphBackend: graphBackend == "keyword" ? "keyword" : "mlx", woven: woven,
                                  aiiHomePath: apart ? home.root.path : nil)
        try ThreadLauncher.config(for: record).write(home: home)
        try record.write()
        return record
    }

    // MARK: - Start and stop

    /// Starts (or adopts) the record's Thread and records the shape it runs with. A woven Thread
    /// registers with `mothership`; one that runs registered elsewhere must be restarted first.
    public static func start(_ record: ThreadRecord, mothership: AIIPorts?, reseed: Bool,
                             main: AIIHome = .resolved()) async throws -> (ServerHandle, LaunchShape) {
        let binary = ThreadLauncher.serverBinary(main: main)
        guard FileManager.default.isExecutableFile(atPath: binary.path) else { throw FabricError.noServer(binary.path) }
        let home = record.aiiHome
        if reseed, let fabric = try main.readSecret(for: WeaveIdentity.app) { try FabricSeeding.reseed(home: home, fabric: fabric) }
        try FabricSeeding.shareModels(home: home, root: record.fabricRoot)
        let spec = ThreadLauncher.threadSpec(record, mothership: mothership, executable: binary)
        let server = try ThreadLauncher.server(spec, home: home)
        let handle = try await server.ensureRunning(timeout: 120)
        FabricService.servers.put(record.name, server)
        let registered = record.woven ? mothership?.grpc : nil
        // Adopted: the sidecar says what it runs with; launched now: this call's shape.
        let shape = handle.adopted
            ? (LaunchShape.load(home: home) ?? LaunchShape(mothershipGRPCPort: nil, graphBackend: record.graphBackend, launchedAt: Date()))
            : LaunchShape(mothershipGRPCPort: registered, graphBackend: record.graphBackend, launchedAt: Date())
        try? shape.write(home: home)
        return (handle, shape)
    }

    public static func stop(_ record: ThreadRecord) async {
        let home = record.aiiHome
        if let server = FabricService.servers.remove(record.name) {
            await server.stop(grace: 3)
        } else {
            await Task.detached { ManagedServer.stopRecordedSync(home.threadRunRecord, grace: 3) }.value
        }
        LaunchShape.remove(home: home)
    }

    /// Whether a running Thread must restart to register with `mothership` (or to stop registering).
    public static func needsRestart(record: ThreadRecord, shape: LaunchShape?, mothership: AIIPorts?) -> Bool {
        let wanted = record.woven ? mothership?.grpc : nil
        guard let shape else { return true }
        return shape.mothershipGRPCPort != wanted
    }

    public static func message(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }
}
