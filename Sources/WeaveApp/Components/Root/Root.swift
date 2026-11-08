//
//  Root.swift
//  Weave
//
//  The window's root component: the sidebar, the four pages kept alive in a PaneStack, the host
//  and the port in the toolbar, the alerts and the spawn sheet.
//

import Granite
import SwiftUI
import WeaveKit

struct Root: GraniteComponent {
    @Command var center: Center
    @Relay var shell: ShellService
    @Relay var settings: SettingsService
    @Relay var host: HostService
    @Relay var port: PortService
    @StateObject var clock = RelayClock([RelayClock.on(ShellService.self), RelayClock.on(HostService.self),
                                         RelayClock.on(PortService.self)])
}
