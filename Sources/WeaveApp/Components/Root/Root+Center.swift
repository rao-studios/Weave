//
//  Root+Center.swift
//  Weave
//

import Granite

extension Root {
    /// Everything the shell shows is a service's (AppKit sets it too); nothing is the root's own.
    struct Center: GraniteCenter {
        struct State: GraniteState {}
        @Store var state: State
    }
}
