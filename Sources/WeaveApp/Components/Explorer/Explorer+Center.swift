//
//  Explorer+Center.swift
//  Weave
//

import Granite
import WeaveKit

extension Explorer {
    struct Center: GraniteCenter {
        struct State: GraniteState {
            var tab: Pane = .stats
            var queryDraft = ""
            var topK = 10
            var entityDraft = ""
            var graphQueryDraft = ""
            var hops = 1
            var depositDraft = ""
            var depositName = ""
        }
        @Store var state: State
    }
}
