//
//  Root+View.swift
//  Weave
//

import Granite
import SwiftUI
import WeaveKit

extension Root {
    var view: some View {
        let mode = shell.state.mode
        return HStack(spacing: 0) {
            if shell.state.sidebarVisible {
                HStack(spacing: 0) {
                    Sidebar().frame(width: WeaveMetrics.sidebarWidth)
                    Divider().background(Color.weaveBorder)
                }
                .transition(.move(edge: .leading))
            }
            PaneStack(active: AppMode.allCases.firstIndex(of: mode) ?? 0) {
                Fabric().paneVisible(mode == .fabric)
                Explorer().paneVisible(mode == .explorer)
                Search().paneVisible(mode == .search)
                Settings().paneVisible(mode == .settings)
            }
            .frame(minWidth: WeaveMetrics.detailMinWidth, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: WeaveMetrics.windowMinSize.width, minHeight: WeaveMetrics.contentMinHeight)
        .background(Color.weaveBG)
        .navigationTitle("Weave")
        .navigationSubtitle(mode.title)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { WeaveAppRoot.shared.toggleSidebar() } label: {
                    Label(shell.state.sidebarVisible ? "Hide Sidebar" : "Show Sidebar", systemImage: "sidebar.left")
                }
                .help("Show or hide the sidebar (⌃⌘S)")
            }
            ToolbarItem(placement: .primaryAction) { HostChip(state: host.state) }
            ToolbarItem(placement: .primaryAction) { PortChip(state: port.state) }
            ToolbarItem(placement: .primaryAction) {
                Button { WeaveAppRoot.shared.showSpawn() } label: { Label("Spawn AII", systemImage: "plus") }
                    .help("Spawn a new AII (⌘N)")
            }
        }
        .preferredColorScheme(.light)
        .task(id: settings.isLoaded) {
            guard settings.isLoaded else { return }
            WeaveAppRoot.shared.start()
        }
        .alert(shell.state.error?.title ?? "Error", isPresented: errorPresented, presenting: shell.state.error) { _ in
            Button("OK") { shell.set(.error(nil)) }
        } message: { e in
            Text(e.message)
        }
        .alert("Remove \(shell.state.pendingRemove ?? "")?", isPresented: removePresented, presenting: shell.state.pendingRemove) { name in
            Button("Remove", role: .destructive) { WeaveAppRoot.shared.remove(name) }
            Button("Cancel", role: .cancel) { shell.set(.pendingRemove(nil)) }
        } message: { name in
            Text("This stops \(name)'s Thread and deletes its home: its index, its graph and its secrets. The shared models stay.")
        }
        .alert(storageTitle, isPresented: storagePresented, presenting: shell.state.pendingStorage) { action in
            Button(action == .uninstall ? "Remove Weave" : "Remove All", role: .destructive) {
                shell.set(.pendingStorage(nil))
                if action == .uninstall { WeaveAppRoot.shared.uninstall() } else { WeaveAppRoot.shared.removeAll() }
            }
            Button("Cancel", role: .cancel) { shell.set(.pendingStorage(nil)) }
        } message: { action in
            Text(action == .uninstall
                 ? "This stops and deletes every AII Weave spawned, deletes Weave's folder, and takes Weave's secret and lane out of ~/.rao. The main AII and the shared models stay. Weave then quits; drag it to the Trash to finish."
                 : "This stops and deletes every AII Weave spawned: their indexes, graphs and secrets. The shared models stay.")
        }
        .sheet(isPresented: Binding(get: { shell.state.spawnSheet }, set: { shell.set(.spawnSheet($0)) })) {
            SpawnSheet(defaultBackend: settings.state.defaultGraphBackend, root: settings.state.rootFolder)
                .onBubble {
                    On(.spawnSheetSubmit, SpawnRequest.self) { request in
                        shell.set(.spawnSheet(false))
                        WeaveAppRoot.shared.spawn(name: request.name, graphBackend: request.graphBackend)
                    }
                    On(.spawnSheetCancel) { shell.set(.spawnSheet(false)) }
                }
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { shell.state.error != nil }, set: { if !$0 { shell.set(.error(nil)) } })
    }

    private var storageTitle: String {
        shell.state.pendingStorage == .uninstall ? "Remove Weave from this Mac?" : "Remove every spawned AII?"
    }

    private var storagePresented: Binding<Bool> {
        Binding(get: { shell.state.pendingStorage != nil }, set: { if !$0 { shell.set(.pendingStorage(nil)) } })
    }

    private var removePresented: Binding<Bool> {
        Binding(get: { shell.state.pendingRemove != nil }, set: { if !$0 { shell.set(.pendingRemove(nil)) } })
    }
}
