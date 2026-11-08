//
//  MainMenu.swift
//  Weave
//

import AppKit

enum MainMenu {
    @MainActor
    static func build(target: AppDelegate) -> NSMenu {
        let main = NSMenu()

        let app = NSMenu(title: "Weave")
        app.addItem(withTitle: "About Weave", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(item("Settings…", #selector(AppDelegate.showSettings(_:)), ",", target))
        app.addItem(.separator())
        app.addItem(withTitle: "Hide Weave", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = app.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Quit Weave", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(submenu(app))

        let file = NSMenu(title: "Fabric")
        file.addItem(item("Spawn AII…", #selector(AppDelegate.spawnAII(_:)), "n", target))
        file.addItem(item("Rescan", #selector(AppDelegate.rescan(_:)), "r", target))
        file.addItem(.separator())
        file.addItem(item("Start All", #selector(AppDelegate.startAll(_:)), "", target))
        file.addItem(item("Stop All", #selector(AppDelegate.stopAll(_:)), "", target))
        file.addItem(.separator())
        file.addItem(item("Choose Folder…", #selector(AppDelegate.chooseRoot(_:)), "o", target))
        file.addItem(item("Reveal Folder in Finder", #selector(AppDelegate.revealRoot(_:)), "", target))
        file.addItem(item("Copy Weave's Port URL", #selector(AppDelegate.copyPortURL(_:)), "", target))
        main.addItem(submenu(file))

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(submenu(edit))

        let view = NSMenu(title: "View")
        view.addItem(item("Fabric", #selector(AppDelegate.showFabric(_:)), "1", target))
        view.addItem(item("Explorer", #selector(AppDelegate.showExplorer(_:)), "2", target))
        view.addItem(item("Search", #selector(AppDelegate.showSearch(_:)), "3", target))
        view.addItem(.separator())
        let sidebar = item("Hide Sidebar", #selector(AppDelegate.toggleSidebarVisibility(_:)), "s", target)
        sidebar.keyEquivalentModifierMask = [.command, .control]
        view.addItem(sidebar)
        main.addItem(submenu(view))

        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        main.addItem(submenu(window))
        NSApp.windowsMenu = window

        return main
    }

    private static func item(_ title: String, _ action: Selector, _ key: String, _ target: AnyObject) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        return item
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }
}
