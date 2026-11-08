//
//  HostService.Set.swift
//  WeaveKit
//

import Foundation
import Granite

extension HostService {
    public struct Set: GraniteReducer {
        public typealias Center = HostService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public enum Kind: Sendable {
                case selected(HostSelection, HostTarget)
                case sewn(ServerStatus)
                case mainPhase(String?)
                case nodes([HostNode], Date)
                case rewoven([String])
                case switched
                case polling(Bool, interval: Double)
                case failed(String?)
                case clear
            }
            public var kind: Kind
            public init(kind: Kind) { self.kind = kind }
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            HostOps.apply(meta.kind, to: &state)
        }

        /// Every send arrives on main through `onMain`: committed there at once, so a ticket
        /// resolved after `MainQueue.flush()` is read back with its writes in.
        public var thread: DispatchQueue? { nil }
    }
}
