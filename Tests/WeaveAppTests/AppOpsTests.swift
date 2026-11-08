//
//  AppOpsTests.swift
//  WeaveAppTests
//

import Testing
import WeaveKit
@testable import Weave

@Suite struct SettingsOpsTests {
    @Test func theStoreKeyIsVersioned() {
        #expect(SettingsService.persistenceKey.hasSuffix(".0001"))
        #expect(SettingsService.persistenceKey.hasPrefix("weave.settings"))
    }

    @Test func theDefaultsAreWeaves() {
        let state = SettingsService.Center.State()
        #expect(state.rootFolder == "~/.rao/weave")
        #expect(state.port == 47600 && state.requireSecretOnPort && state.portEnabled)
        #expect(!state.stopThreadsOnQuit && state.defaultGraphBackend == "mlx")
    }

    @Test func everyValueIsClampedToItsRange() {
        var state = SettingsService.Center.State()
        SettingsOps.apply(.write {
            $0.port = 80; $0.healthInterval = 0; $0.softCap = 400; $0.defaultGraphBackend = "magic"; $0.rootFolder = "  "; $0.searchTopK = 0
        }, to: &state)
        #expect(state.port == 1024 && state.healthInterval == 1 && state.softCap == 39)
        #expect(state.defaultGraphBackend == "mlx" && state.rootFolder == "~/.rao/weave" && state.searchTopK == 1)
        SettingsOps.apply(.reset, to: &state)
        #expect(state.port == 47600)
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
