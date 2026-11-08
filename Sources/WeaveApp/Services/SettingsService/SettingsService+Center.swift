//
//  SettingsService+Center.swift
//  Weave
//

import Foundation
import Granite
import WeaveKit

extension SettingsService {
    struct Center: GraniteCenter {
        /// Persisted: every field is Codable and has its default here.
        struct State: GraniteState {
            /// Where spawned AIIs live. It does not have to be under ~/.rao.
            var rootFolder: String = FabricRoot.defaultPath
            var healthInterval: Double = 3
            var hostPollInterval: Double = 5
            var portEnabled = true
            var port: Int = WeaveIdentity.defaultPort
            /// /v1/* on Weave's port wants Weave's secret.
            var requireSecretOnPort = true
            /// Quitting stops the spawned Threads (and a host Sewn Weave started); off, they keep serving.
            var stopThreadsOnQuit = false
            /// `mlx` (on-device graph extraction) or `keyword`.
            var defaultGraphBackend: String = "mlx"
            var softCap: Int = FabricService.defaultSoftCap
            var searchTopK: Int = 10
            init() {}
        }

        @Event var set: Set.Reducer
        @Store(persist: SettingsService.persistenceKey, autoSave: true, preload: true) var state: State
        init() {}
    }
}
