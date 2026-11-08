//
//  FabricService.Set.swift
//  WeaveKit
//
//  The service's one writer: every transition is a `Kind`, applied by FabricOps.apply.
//

import Foundation
import Granite

extension FabricService {
    public struct Set: GraniteReducer {
        public typealias Center = FabricService.Center
        public init() {}

        public struct Meta: GranitePayload {
            public enum Kind: Sendable {
                case scanning(Bool)
                case scanned(FabricScan)
                case record(ThreadRecord)
                case removed(String)
                case probe(String, ThreadProbe)
                case status(String, ThreadStatus)
                case shape(String, LaunchShape?)
                case reseeded(String)
                case idle(String)
                case loop(Bool, interval: Double)
                case ticked(Date)
                case disk(Int64, Date)
                case failed(String?)
                case clear
            }
            public var kind: Kind
            public init(kind: Kind) { self.kind = kind }
        }

        @Payload public var meta: Meta?

        public func reduce(state: inout Center.State) {
            guard let meta else { return }
            FabricOps.apply(meta.kind, to: &state)
        }

        /// Every send arrives on main through `onMain`: committed there at once, so a ticket
        /// resolved after `MainQueue.flush()` is read back with its writes in.
        public var thread: DispatchQueue? { nil }
    }
}
