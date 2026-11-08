//
//  Connect+Center.swift
//  Weave
//

import Granite

extension Connect {
    struct Center: GraniteCenter {
        /// The example whose code was copied last, for a moment's confirmation.
        struct State: GraniteState {
            var copied: String?
        }
        @Store var state: State
    }
}
