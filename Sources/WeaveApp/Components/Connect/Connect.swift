//
//  Connect.swift
//  Weave
//
//  How another app talks to Weave: the requests that list its AIIs, file a record into one, search one
//  or all, and list one's records, in curl, Swift or JavaScript, each to copy and to run here first.
//

import Granite
import SwiftUI
import WeaveKit

struct Connect: GraniteComponent {
    @Command var center: Center
    @Relay var connect: ConnectService
    @Relay var fabric: FabricService
    @Relay var port: PortService
    @StateObject var clock = RelayClock([RelayClock.on(ConnectService.self), RelayClock.on(PortService.self)])
}
