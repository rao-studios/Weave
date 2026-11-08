//
//  PortService.Set.swift
//  WeaveKit
//

import Foundation
import Granite

extension PortService {
    public struct Set: GraniteReducer {
        public typealias Center = PortService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public enum Kind: Sendable {
                case listening(Bool, generation: Int)
                case served(String, Date)
                case failed(String?, generation: Int)
                case clear
            }
            public var kind: Kind
            public init(kind: Kind) { self.kind = kind }
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            PortOps.apply(meta.kind, to: &state)
        }

        /// Every send arrives on main through `onMain`: committed there at once, so a ticket
        /// resolved after `MainQueue.flush()` is read back with its writes in.
        public var thread: DispatchQueue? { nil }
    }
}
