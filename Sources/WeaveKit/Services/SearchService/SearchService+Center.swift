//
//  SearchService+Center.swift
//  WeaveKit
//

import Foundation
import Granite

extension SearchService {
    public struct Center: GraniteCenter {
        public struct State: TransientState {
            public var query: String = ""
            public var hits: [SearchHit] = []
            public var graph: SearchTrace?
            public var searching = false
            public var latencyMs: Double?
            public var lastError: String?
            /// The query in flight; an answer to an older one is dropped.
            public var epoch = 0
            public init() {}

            /// The instances that answered, in rank order.
            public var answeredBy: [String] {
                var seen: [String] = []
                for name in hits.compactMap(\.threadName) where !seen.contains(name) { seen.append(name) }
                return seen
            }
        }

        @Event public var set: Set.Reducer
        @Event public var query: Query.Reducer
        @Store public var state: State
        public init() {}
    }
}
