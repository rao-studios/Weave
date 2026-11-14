//
//  Fabric.swift
//  Weave
//
//  The fabric page: the host and the AIIs Weave spawned, each with its ports, its Thread's state,
//  its counts, and whether it is woven into the host; as a grid of cards a page at a time (2 × 3 by
//  default) or as a list. The layout and the grid's size are settings, so they are kept.
//

import Granite
import SwiftUI
import WeaveKit

struct Fabric: GraniteComponent {
    @Command var center: Center
    @Relay var fabric: FabricService
    @Relay var host: HostService
    @Relay var settings: SettingsService
    @StateObject var clock = RelayClock([RelayClock.on(FabricService.self), RelayClock.on(HostService.self),
                                         RelayClock.on(SettingsService.self)])
    /// The grid's page at the leading edge: the scroll's, so it is the view's own.
    @State var gridPage: Int?

    /// The page's width on a wide window, unless the grid asks for more columns than fit in it.
    static let maxPageWidth: CGFloat = 1180
}
