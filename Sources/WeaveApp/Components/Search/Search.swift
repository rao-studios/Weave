//
//  Search.swift
//  Weave
//
//  The federated search: one query to the host's Sewn, which fans it out to every woven Thread
//  and merges their partitions by score. Each hit is named by the AII whose Thread answered.
//

import Granite
import SwiftUI
import WeaveKit

struct Search: GraniteComponent {
    @Command var center: Center
    @Relay var search: SearchService
    @Relay var host: HostService
    @Relay var fabric: FabricService
    @Relay var port: PortService
    @Relay var settings: SettingsService
    @StateObject var clock = RelayClock([RelayClock.on(SearchService.self), RelayClock.on(HostService.self)])
}
