//
//  HostService+Center.swift
//  WeaveKit
//

import Foundation
import Granite

extension HostService {
    public struct Center: GraniteCenter {
        public struct State: TransientState {
            public var selection: HostSelection = .main
            public var target: HostTarget?
            public var sewn: ServerStatus = .unknown
            /// The main AII's phase, from its supervisor, while it is the host.
            public var mainPhase: String?
            public var nodes: [HostNode] = []
            /// The Select in flight; a second is refused until it lands.
            public var switching: UUID?
            /// The Threads the last switch restarted onto this host.
            public var rewoven: [String] = []
            public var pollInterval: Double = 5
            public var polling = false
            public var lastPolled: Date?
            public var lastError: String?
            public init() {}

            public var isSwitching: Bool { switching != nil }
        }

        @Event public var set: Set.Reducer
        @Event public var select: Select.Reducer
        @Event public var watch: Watch.Reducer
        @Store public var state: State
        public init() {}
    }
}
