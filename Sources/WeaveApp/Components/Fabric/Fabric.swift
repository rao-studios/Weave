//
//  Fabric.swift
//  Weave
//
//  The fabric page: the host and the AIIs Weave spawned, each with its ports, its Thread's state,
//  its counts, and whether it is woven into the host.
//

import Granite
import SwiftUI
import WeaveKit

struct Fabric: GraniteComponent {
    @Command var center: Center
    @Relay var fabric: FabricService
    @Relay var host: HostService
    @Relay var settings: SettingsService
    @StateObject var clock = RelayClock([RelayClock.on(FabricService.self), RelayClock.on(HostService.self)])
}
