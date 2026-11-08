//
//  ExplorerService+Center.swift
//  WeaveKit
//

import Foundation
import Granite

extension ExplorerService {
    public struct Center: GraniteCenter {
        public struct State: TransientState {
            public var selected: ThreadRef?
            public var stats: AIIStats?
            public var embedder: ThreadEmbedderState?
            public var extractor: String?
            public var library: [LibraryGroup] = []
            public var graph: GraphSnapshot?
            public var hits: [ThreadHit] = []
            public var lastDeposit: String?
            public var log: [String] = []
            public var loading: Swift.Set<Pane> = []
            public var errors: [Pane: String] = [:]
            public init() {}

            public func isLoading(_ pane: Pane) -> Bool { loading.contains(pane) }
            public var documentCount: Int { library.reduce(0) { $0 + $1.documents.count } }
        }

        @Event public var set: Set.Reducer
        @Event public var load: Load.Reducer
        @Store public var state: State
        public init() {}
    }
}
