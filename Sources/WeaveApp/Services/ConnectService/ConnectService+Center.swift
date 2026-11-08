//
//  ConnectService+Center.swift
//  Weave
//

import Foundation
import Granite
import WeaveKit

extension ConnectService {
    struct Center: GraniteCenter {
        struct State: TransientState {
            /// The AII the examples name: a spawned AII's name, or `main`.
            var thread: String?
            var format: RequestFormat = .curl
            var results: [String: ConnectOps.Result] = [:]
            var running: Swift.Set<String> = []
            init() {}
        }

        @Event var set: Set.Reducer
        @Event var run: Run.Reducer
        @Store var state: State
        init() {}
    }
}
