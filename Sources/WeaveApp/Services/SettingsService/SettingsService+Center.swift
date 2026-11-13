//
//  SettingsService+Center.swift
//  Weave
//

import Foundation
import Granite
import WeaveKit

extension SettingsService {
    struct Center: GraniteCenter {
        /// Persisted: every field is Codable and has its default here. Decoding takes each field
        /// only when present, so adding one never discards the rest of a saved file.
        struct State: GraniteState {
            /// On: spawned AIIs live in `customLocation`. Off (the default): in Weave's own folder.
            var useCustomLocation = false
            /// The folder last chosen, kept while the toggle is off so turning it on again finds it.
            var customLocation: String = ""
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
            /// The Fabric page: a grid of cards (the default, 2 × 2 to a page) or a list.
            var fabricLayout: FabricLayout = .grid
            var fabricGrid: FabricGridSize = .standard
            init() {}

            /// Where spawned AIIs live now.
            var rootFolder: String {
                useCustomLocation && !customLocation.isEmpty ? customLocation : FabricRoot.defaultPath
            }

            private enum CodingKeys: String, CodingKey {
                case useCustomLocation, customLocation, healthInterval, hostPollInterval, portEnabled, port
                case requireSecretOnPort, stopThreadsOnQuit, defaultGraphBackend, softCap, searchTopK
                case fabricLayout, fabricGrid
            }

            /// Before the toggle, one `rootFolder` field held the folder in use.
            private enum LegacyKeys: String, CodingKey { case rootFolder }

            init(from decoder: Decoder) throws {
                self.init()
                let c = try decoder.container(keyedBy: CodingKeys.self)
                func take<V: Decodable>(_ key: CodingKeys, _ field: inout V) {
                    if let value = try? c.decodeIfPresent(V.self, forKey: key) { field = value }
                }
                take(.useCustomLocation, &useCustomLocation)
                take(.customLocation, &customLocation)
                take(.healthInterval, &healthInterval)
                take(.hostPollInterval, &hostPollInterval)
                take(.portEnabled, &portEnabled)
                take(.port, &port)
                take(.requireSecretOnPort, &requireSecretOnPort)
                take(.stopThreadsOnQuit, &stopThreadsOnQuit)
                take(.defaultGraphBackend, &defaultGraphBackend)
                take(.softCap, &softCap)
                take(.searchTopK, &searchTopK)
                take(.fabricLayout, &fabricLayout)
                take(.fabricGrid, &fabricGrid)
                let legacy = try decoder.container(keyedBy: LegacyKeys.self)
                if !c.contains(.customLocation), let folder = try? legacy.decodeIfPresent(String.self, forKey: .rootFolder),
                   FabricRoot.url(folder) != FabricRoot.url(FabricRoot.defaultPath) {
                    customLocation = folder
                    useCustomLocation = true
                }
            }
        }

        @Event var set: Set.Reducer
        @Store(persist: SettingsService.persistenceKey, autoSave: true, preload: true) var state: State
        init() {}
    }
}
