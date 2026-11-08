//
//  Search+Center.swift
//  Weave
//

import Granite

extension Search {
    struct Center: GraniteCenter {
        struct State: GraniteState {
            var draft = ""
        }
        @Store var state: State
    }
}
