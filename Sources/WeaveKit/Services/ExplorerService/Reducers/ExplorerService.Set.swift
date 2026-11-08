//
//  ExplorerService.Set.swift
//  WeaveKit
//

import Foundation
import Granite

extension ExplorerService {
    public struct Set: GraniteReducer {
        public typealias Center = ExplorerService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public enum Kind: Sendable {
                case selected(ThreadRef?)
                case stats(ThreadRef, AIIStats, ThreadHealth)
                case library(ThreadRef, [LibraryGroup])
                case graph(ThreadRef, GraphSnapshot)
                case hits(ThreadRef, [ThreadHit])
                case deposited(ThreadRef, String)
                case log(ThreadRef, [String])
                case failed(ThreadRef, Pane, String)
                case clearAll
            }
            public var kind: Kind
            public init(kind: Kind) { self.kind = kind }
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            ExplorerOps.apply(meta.kind, to: &state)
        }

        /// Every send arrives on main through `onMain`: committed there at once, so a ticket
        /// resolved after `MainQueue.flush()` is read back with its writes in.
        public var thread: DispatchQueue? { nil }
    }
}
