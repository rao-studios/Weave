//
//  Settings.swift
//  Weave
//

import Granite
import SwiftUI
import WeaveKit

struct Settings: GraniteComponent {
    @Command var center: Center
    @Relay var settings: SettingsService
    @Relay var fabric: FabricService
    @Relay var port: PortService
    @StateObject var clock = RelayClock([RelayClock.on(SettingsService.self), RelayClock.on(PortService.self)])
}
