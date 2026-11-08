//
//  Settings+Center.swift
//  Weave
//

import Granite

extension Settings {
    struct Center: GraniteCenter {
        struct State: GraniteState {}
        @Store var state: State
    }
}
