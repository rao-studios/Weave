//
//  AppDelegate.swift
//  Weave
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var window: NSWindow?
    let root = WeaveAppRoot.shared

    // Before the first window, so the Dock never shows the generic icon in between.
    func applicationWillFinishLaunching(_ notification: Notification) {
        DockIcon.applyIfUnbundled()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The palette is light-only; keep the chrome, popovers and menus light with it.
        NSApp.appearance = NSAppearance(named: .aqua)
        NSApp.mainMenu = MainMenu.build(target: self)
        root.launch(arguments: CommandLine.arguments)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: WeaveMetrics.windowSize),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Weave"
        window.toolbarStyle = .unified
        let host = NSHostingView(rootView: Root())
        host.sceneBridgingOptions = [.toolbars, .title]
        host.sizingOptions = []
        window.contentView = host
        window.contentMinSize = WeaveMetrics.windowMinSize
        window.center()
        window.setFrameAutosaveName("WeaveMainWindow")
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        root.shutdown()
    }

    // MARK: - Menu actions

    @objc func spawnAII(_ sender: Any?) { root.showSpawn() }
    @objc func rescan(_ sender: Any?) { root.rescan() }
    @objc func startAll(_ sender: Any?) { root.startAll() }
    @objc func stopAll(_ sender: Any?) { root.stopAll() }
    @objc func revealRoot(_ sender: Any?) { root.revealRoot() }
    @objc func chooseRoot(_ sender: Any?) { root.chooseRoot() }
    @objc func showFabric(_ sender: Any?) { root.show(.fabric) }
    @objc func showExplorer(_ sender: Any?) { root.show(.explorer) }
    @objc func showSearch(_ sender: Any?) { root.show(.search) }
    @objc func showSettings(_ sender: Any?) { root.show(.settings) }
    @objc func toggleSidebarVisibility(_ sender: Any?) { root.toggleSidebar() }
    @objc func copyPortURL(_ sender: Any?) { root.copyPortURL() }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleSidebarVisibility(_:)) {
            menuItem.title = root.shell.state.sidebarVisible ? "Hide Sidebar" : "Show Sidebar"
        }
        return true
    }
}
