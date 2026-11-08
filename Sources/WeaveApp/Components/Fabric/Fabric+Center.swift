//
//  Fabric+Center.swift
//  Weave
//

import Granite

extension Fabric {
    struct Center: GraniteCenter {
        struct State: GraniteState {
            var hovered: String?
        }
        @Store var state: State
    }
}
