//
//  PortService+Center.swift
//  WeaveKit
//

import Foundation
import Granite

extension PortService {
    public struct Center: GraniteCenter {
        public struct State: TransientState {
            public var port: Int = WeaveIdentity.defaultPort
            public var enabled = false
            public var listening = false
            public var requireSecret = true
            public var served = 0
            public var lastPath: String?
            public var lastRequest: Date?
            public var lastError: String?
            /// Bumps per server start: a late write from a replaced server is dropped.
            public var generation = 0
            public init() {}

            public var baseURL: String { "http://127.0.0.1:\(port)" }
        }

        @Event public var set: Set.Reducer
        @Event public var serve: Serve.Reducer
        @Store public var state: State
        public init() {}
    }
}
