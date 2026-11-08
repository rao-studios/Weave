//
//  SettingsOps.swift
//  Weave
//

import Foundation

enum SettingsOps {
    typealias State = SettingsService.Center.State

    static func apply(_ kind: SettingsService.Set.Meta.Kind, to state: inout State) {
        switch kind {
        case .write(let body):
            body(&state)
            clamp(&state)
        case .reset:
            state = State()
        }
    }

    /// Keeps every value in its range, whatever a control or a stale file wrote.
    static func clamp(_ state: inout State) {
        state.healthInterval = min(max(state.healthInterval, 1), 60)
        state.hostPollInterval = min(max(state.hostPollInterval, 1), 60)
        state.port = min(max(state.port, 1024), 65535)
        state.softCap = min(max(state.softCap, 1), 39)
        state.searchTopK = min(max(state.searchTopK, 1), 50)
        if state.defaultGraphBackend != "keyword" { state.defaultGraphBackend = "mlx" }
        if state.rootFolder.trimmingCharacters(in: .whitespaces).isEmpty { state.rootFolder = "~/.rao/weave" }
    }
}
