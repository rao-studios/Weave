//
//  AppOpsTests.swift
//  WeaveAppTests
//

import Foundation
import Testing
import WeaveKit
@testable import Weave

@Suite struct SettingsOpsTests {
    @Test func theStoreKeyIsVersioned() {
        #expect(SettingsService.persistenceKey.hasSuffix(".0002"))
        #expect(SettingsService.persistenceKey.hasPrefix("weave.settings"))
    }

    @Test func theDefaultsAreWeaves() {
        let state = SettingsService.Center.State()
        #expect(state.rootFolder == FabricRoot.defaultPath && !state.rootFolder.contains(".rao"))
        #expect(!state.useCustomLocation && state.customLocation.isEmpty, "a custom location is never the default")
        #expect(state.port == 47600 && state.requireSecretOnPort && state.portEnabled)
        #expect(!state.stopThreadsOnQuit && state.defaultGraphBackend == "mlx")
    }

    @Test func everyValueIsClampedToItsRange() {
        var state = SettingsService.Center.State()
        SettingsOps.apply(.write {
            $0.port = 80; $0.healthInterval = 0; $0.softCap = 400; $0.defaultGraphBackend = "magic"; $0.searchTopK = 0
            $0.useCustomLocation = true; $0.customLocation = "  "
        }, to: &state)
        #expect(state.port == 1024 && state.healthInterval == 1 && state.softCap == 39)
        #expect(state.defaultGraphBackend == "mlx" && state.searchTopK == 1)
        #expect(!state.useCustomLocation && state.rootFolder == FabricRoot.defaultPath, "on with no folder is off")
        SettingsOps.apply(.reset, to: &state)
        #expect(state.port == 47600)
    }
}

@Suite struct CustomLocationTests {
    typealias State = SettingsService.Center.State

    @Test func theFolderIsKeptWhileTheToggleIsOff() throws {
        var state = State()
        SettingsOps.apply(.write { $0.customLocation = "/Volumes/T9/rao/weave"; $0.useCustomLocation = true }, to: &state)
        #expect(state.rootFolder == "/Volumes/T9/rao/weave")
        SettingsOps.apply(.write { $0.useCustomLocation = false }, to: &state)
        #expect(state.rootFolder == FabricRoot.defaultPath && state.customLocation == "/Volumes/T9/rao/weave")
        let restored = try JSONDecoder().decode(State.self, from: JSONEncoder().encode(state))
        #expect(restored.customLocation == "/Volumes/T9/rao/weave" && !restored.useCustomLocation)
        #expect(String(decoding: try JSONEncoder().encode(state), as: UTF8.self).contains("rootFolder") == false)
    }

    @Test func aFileMissingFieldsKeepsTheRest() throws {
        let state = try JSONDecoder().decode(State.self, from: Data(#"{"port": 47700, "searchTopK": 20}"#.utf8))
        #expect(state.port == 47700 && state.searchTopK == 20 && state.portEnabled && !state.useCustomLocation)
    }

    @Test func anEarlierFilesFolderBecomesTheCustomLocation() throws {
        let chosen = try JSONDecoder().decode(State.self, from: Data(#"{"rootFolder": "/Volumes/Work/aiis", "port": 47600}"#.utf8))
        #expect(chosen.useCustomLocation && chosen.customLocation == "/Volumes/Work/aiis")
        let defaulted = try JSONDecoder().decode(State.self, from: Data(#"{"rootFolder": "~/Library/Application Support/Weave/AIIs"}"#.utf8))
        #expect(!defaulted.useCustomLocation && defaulted.customLocation.isEmpty)
    }
}

@Suite struct ShellOpsTests {
    @Test func selectingAThreadOpensTheExplorer() {
        var state = ShellService.Center.State()
        ShellOps.apply(.select(.spawned("alpha")), to: &state)
        #expect(state.mode == .explorer && state.selectedThread == .spawned("alpha"))
        ShellOps.apply(.select(nil), to: &state)
        #expect(state.mode == .explorer && state.selectedThread == nil)
    }

    @Test func modeArgumentsAreRead() {
        let kinds = ShellOps.launchKinds(["Weave", "--mode=search", "--mode=nope"])
        var state = ShellService.Center.State()
        for kind in kinds { ShellOps.apply(kind, to: &state) }
        #expect(kinds.count == 1 && state.mode == .search)
    }
}
