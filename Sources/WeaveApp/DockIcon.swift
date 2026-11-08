//
//  DockIcon.swift
//  Weave
//
//  scripts/dev/dev.sh runs Weave as a bare executable, which the Dock shows with the generic icon.
//  Outside a bundle, set Weave's own (Resources/AppIcon.png, the pre-rounded tile). A bundled
//  Weave.app takes its layered icon from Assets.car, so a bundle is left alone. The bundle check
//  comes first: Bundle.module traps when its resources are missing.
//

import AppKit

enum DockIcon {
    @MainActor
    static func applyIfUnbundled() {
        guard Bundle.main.bundleURL.pathExtension != "app",
              let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return }
        NSApp.applicationIconImage = image
    }
}
