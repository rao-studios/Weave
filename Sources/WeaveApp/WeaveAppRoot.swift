//
//  WeaveAppRoot.swift
//  Weave
//
//  The app's root: a main-actor object that holds a relay to every service for the life of the
//  process, boots the fabric, the host and the port once Settings have loaded, and is the façade
//  AppKit (the menus, the delegate) and the pages call for anything that crosses services: a spawn
//  starts on the host's mothership; a host switch re-weaves the Threads.
//

import AppKit
import Foundation
import Granite
import SwiftUI
import WeaveKit

@MainActor
final class WeaveAppRoot {
    static let shared: WeaveAppRoot = {
        GraniteLogger.currentLevel = .error
        return WeaveAppRoot()
    }()

    @Relay(.silence) var settings: SettingsService
    @Relay(.silence) var shell: ShellService
    @Relay(.silence) var fabric: FabricService
    @Relay(.silence) var host: HostService
    @Relay(.silence) var port: PortService
    @Relay(.silence) var search: SearchService
    @Relay(.silence) var explorer: ExplorerService
    @Relay(.silence) var connect: ConnectService

    private var started = false
    /// `--explore=<name>` and `--query=<text>`: what the window opens on (the README's screenshots).
    private var launchExplore: String?
    private var launchQuery: String?

    private init() {}

    /// Before the window exists: `--mode=` takes effect.
    func launch(arguments: [String]) {
        for kind in ShellOps.launchKinds(arguments) { shell.set(kind) }
        launchExplore = ShellOps.argument("--explore=", in: arguments)
        launchQuery = ShellOps.argument("--query=", in: arguments)
    }

    /// The persisted settings restore after the service exists: wait for them.
    func awaitSettingsLoaded() async {
        while !settings.isLoaded { try? await TaskSleep.seconds(0.02) }
    }

    /// Scans the fabric, opens Weave's port, brings the host up, and starts the loops (idempotent).
    func start() {
        guard !started else { return }
        started = true
        Task { await boot() }
    }

    func boot() async {
        let s = settings.state
        do {
            try checkLocation()
            try await fabric.scan(root: s.rootFolder)
        } catch {
            shell.present(AppError("Where the AIIs live", error))
        }
        fabric.watch(interval: s.healthInterval)
        if s.portEnabled { port.start(port: s.port, requireSecret: s.requireSecretOnPort) }
        do {
            try await host.restore(root: s.rootFolder)
        } catch {
            shell.present(AppError("The host", error))
        }
        host.watch(interval: s.hostPollInterval)
        if let name = launchExplore, fabric.state.record(name) != nil { explore(.spawned(name)) }
        if let query = launchQuery {
            await host.poll()
            _ = try? await search.query(query, topK: s.searchTopK)
        }
    }

    /// Quit: the loops and the port stop, Weave's lease on the main AII goes. The spawned Threads
    /// keep running unless Settings say to stop them; the next launch adopts them.
    func shutdown() {
        let stopSpawned = settings.state.stopThreadsOnQuit
        let records = fabric.state.threads
        port.stop()
        fabric.watch(interval: nil)
        host.watch(interval: nil)
        HostService.shutdownSync(stopSpawned: stopSpawned, records: records)
        if stopSpawned { FabricService.stopAllSync(records: records) }
    }

    // MARK: - The façade

    /// The mothership a woven Thread registers with: the host's Sewn, when one is chosen.
    var mothership: AIIPorts? { host.state.target?.sewnPorts }

    func show(_ mode: AppMode) { shell.show(mode) }

    func toggleSidebar() { withAnimation { shell.set(.toggleSidebar) } }

    func showSpawn() {
        show(.fabric)
        shell.set(.spawnSheet(true))
    }

    /// A new AII: provisioned, then started on the host's mothership.
    func spawn(name: String, graphBackend: String) {
        let fabric = self.fabric, shell = self.shell
        let softCap = settings.state.softCap
        let mothership = self.mothership
        Task {
            do {
                try checkLocation()
                let record = try await fabric.spawn(name: name, graphBackend: graphBackend, softCap: softCap)
                try await fabric.start(record.name, mothership: mothership)
            } catch {
                shell.present(AppError("Spawn \(name)", error))
            }
        }
    }

    func start(_ name: String) { run("Start \(name)") { [fabric, mothership] in try await fabric.start(name, mothership: mothership) } }

    func stop(_ name: String) { run("Stop \(name)") { [fabric] in try await fabric.stop(name) } }

    func restart(_ name: String) { run("Restart \(name)") { [fabric, mothership] in try await fabric.restart(name, mothership: mothership) } }

    func setWoven(_ name: String, _ woven: Bool) {
        run(woven ? "Weave \(name) in" : "Weave \(name) out") { [fabric, mothership] in
            try await fabric.weave(name, woven: woven, mothership: mothership)
        }
    }

    func confirmRemove(_ name: String) { shell.set(.pendingRemove(name)) }

    func remove(_ name: String) {
        shell.set(.pendingRemove(nil))
        if shell.state.selectedThread == .spawned(name) { shell.set(.select(nil)); explorer.select(nil) }
        let fabric = self.fabric, host = self.host, root = settings.state.rootFolder
        let wasHost = host.state.selection == .spawned(name)
        run("Remove \(name)") {
            try await fabric.remove(name)
            if wasHost { try await host.select(.main, root: root) }
        }
    }

    func startAll() {
        let fabric = self.fabric, mothership = self.mothership
        let names = fabric.state.threads.map(\.name).filter { !fabric.state.status(of: $0).isRunning }
        run("Start all") { for name in names { try await fabric.start(name, mothership: mothership) } }
    }

    func stopAll() {
        let fabric = self.fabric
        let names = fabric.state.threads.map(\.name).filter { fabric.state.status(of: $0).isRunning }
        run("Stop all") { for name in names { try await fabric.stop(name) } }
    }

    /// Stops and deletes every spawned AII (the host moves back to the main AII first).
    func removeAll() {
        let fabric = self.fabric, host = self.host, root = settings.state.rootFolder
        let names = fabric.state.threads.map(\.name)
        shell.set(.select(nil))
        explorer.select(nil)
        run("Remove all AIIs") {
            if host.state.selection != .main { try await host.select(.main, root: root) }
            for name in names { try await fabric.remove(name) }
            await fabric.measure()
        }
    }

    /// Everything Weave made, gone: every spawned AII, Weave's folder, and Weave's registration
    /// in ~/.rao (its secret and its lane). Then Weave quits; drag it to the Trash to finish.
    func uninstall() {
        let fabric = self.fabric, root = FabricRoot.url(settings.state.rootFolder)
        let names = fabric.state.threads.map(\.name)
        // The location not in use: Weave's own folder, or a custom one turned off but remembered.
        let s = settings.state
        let other = FabricRoot.url(s.useCustomLocation || s.customLocation.isEmpty ? FabricRoot.defaultPath : s.customLocation)
        let shell = self.shell
        Task {
            do {
                port.stop()
                fabric.watch(interval: nil)
                host.watch(interval: nil)
                HostService.shutdownSync(stopSpawned: true, records: fabric.state.threads)
                for name in names { try await fabric.remove(name) }
                FabricRoot.removeFabric(root: root)
                if other != root {
                    FabricService.stopAllSync(records: FabricRoot.records(root: other))
                    FabricRoot.removeFabric(root: other)
                }
                try? FileManager.default.removeItem(at: WeaveIdentity.supportDirectory)
                try FabricSeeding.unregister()
                settings.set(.reset)
                NSApp.terminate(nil)
            } catch {
                shell.present(AppError("Remove Weave", error))
            }
        }
    }

    func selectHost(_ selection: HostSelection) {
        let host = self.host, root = settings.state.rootFolder
        run("Host \(selection)") { try await host.select(selection, root: root) }
    }

    func explore(_ ref: ThreadRef) {
        shell.set(.select(ref))
        explorer.select(ref)
        let explorer = self.explorer
        Task { await explorer.refresh(ref) }
    }

    /// The Connect page, its examples naming `thread` (a spawned AII, or `main`).
    func showConnect(_ thread: String? = nil) {
        if let thread { connect.set(.thread(thread)) }
        show(.connect)
    }

    func rescan() {
        let fabric = self.fabric, root = settings.state.rootFolder
        do { try checkLocation() } catch { shell.present(AppError("Where the AIIs live", error)); return }
        run("Rescan") { try await fabric.scan(root: root) }
    }

    // MARK: - Where the AIIs live

    /// A custom location must already exist (its drive may not be connected): Weave never makes
    /// one in its place. Weave's own folder is made as needed.
    func checkLocation() throws {
        let s = settings.state
        guard s.useCustomLocation else { return }
        try FabricRoot.usable(FabricRoot.url(s.rootFolder), mustExist: true)
    }

    /// The Settings toggle. On with no folder chosen yet opens the panel; off keeps the folder
    /// for next time and goes back to Weave's own.
    func setCustomLocation(_ on: Bool) {
        let s = settings.state
        guard on != s.useCustomLocation else { return }
        if on && s.customLocation.isEmpty { chooseCustomLocation(); return }
        if on {
            do { try FabricRoot.usable(FabricRoot.url(s.customLocation), mustExist: true) } catch {
                shell.present(AppError("Custom location", error))
                return
            }
        }
        relocate { $0.useCustomLocation = on }
    }

    /// Browse for the custom location; a folder that can hold AII homes is kept and used.
    func chooseCustomLocation() {
        let s = settings.state
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use Folder"
        panel.message = "Where Weave keeps the AIIs it spawns. It must be on an APFS or Mac OS Extended volume."
        panel.directoryURL = s.customLocation.isEmpty ? URL(fileURLWithPath: "/Volumes", isDirectory: true)
                                                      : FabricRoot.url(s.customLocation).deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try FabricRoot.usable(url, mustExist: true) } catch {
            shell.present(AppError("Custom location", error))
            return
        }
        let path = url.path
        relocate { $0.customLocation = path; $0.useCustomLocation = true }
    }

    /// Applies a change to where the AIIs live and scans there. Refused while a spawned AII runs:
    /// it would go on serving, and answering the host's searches, from a folder Weave no longer shows.
    private func relocate(_ change: @escaping @Sendable (inout SettingsService.Center.State) -> Void) {
        let before = settings.state.rootFolder
        var after = settings.state
        change(&after)
        let moves = FabricRoot.url(after.rootFolder) != FabricRoot.url(before)
        let running = fabric.state.threads.map(\.name).filter { fabric.state.status(of: $0).isRunning }
        if moves, !running.isEmpty {
            shell.present(AppError("Where the AIIs live", message: "Stop \(running.joined(separator: ", ")) first: a running AII keeps serving from \(FabricRoot.url(before).path)."))
            return
        }
        settings.set(.write(change))
        guard moves else { return }
        let fabric = self.fabric, host = self.host, root = after.rootFolder
        shell.set(.select(nil))
        explorer.select(nil)
        run("Where the AIIs live") {
            try await fabric.scan(root: root)
            try await host.restore(root: root)
        }
    }

    func revealRoot() {
        NSWorkspace.shared.activateFileViewerSelecting([FabricRoot.url(settings.state.rootFolder)])
    }

    func revealHome(_ name: String) {
        guard let record = fabric.state.record(name) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: record.home)])
    }

    func copyPortURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(port.state.baseURL, forType: .string)
    }

    /// Weave's port, restarted with what Settings say now.
    func applyPortSettings() {
        let s = settings.state
        if s.portEnabled { port.start(port: s.port, requireSecret: s.requireSecretOnPort) } else { port.stop() }
    }

    func applyIntervals() {
        fabric.watch(interval: settings.state.healthInterval)
        host.watch(interval: settings.state.hostPollInterval)
    }

    private func run(_ title: String, _ body: @escaping @Sendable () async throws -> Void) {
        let shell = self.shell
        Task {
            do { try await body() } catch { shell.present(AppError(title, error)) }
        }
    }
}
