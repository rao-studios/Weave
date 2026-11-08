//
//  Explorer.swift
//  Weave
//
//  One Thread, explored in Weave's lane: its counts and models, its library, its graph, a search of
//  it alone, a deposit into it, and its log.
//

import Granite
import SwiftUI
import WeaveKit

struct Explorer: GraniteComponent {
    @Command var center: Center
    @Relay var explorer: ExplorerService
    @Relay var shell: ShellService
    @Relay var fabric: FabricService
    @StateObject var clock = RelayClock([RelayClock.on(ExplorerService.self), RelayClock.on(ShellService.self)])
}
