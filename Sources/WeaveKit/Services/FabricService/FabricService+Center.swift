//
//  FabricService+Center.swift
//  WeaveKit
//

import Foundation
import Granite

extension FabricService {
    public struct Center: GraniteCenter {
        /// Mirrors the folder and the processes: read again at every launch, never persisted.
        public struct State: TransientState {
            public var root: String = ""
            public var scanned = false
            public var scanning = false
            public var fabricFingerprint: String?
            public var serverBinary: String = ""
            public var serverInstalled = false
            public var threads: [ThreadRecord] = []
            public var status: [String: ThreadStatus] = [:]
            public var embedder: [String: ThreadEmbedderState] = [:]
            public var extractor: [String: String] = [:]
            public var counts: [String: ThreadCounts] = [:]
            public var shapes: [String: LaunchShape] = [:]
            /// Homes whose stack secret is no longer the FABRIC secret: re-seeded at their next start.
            public var reseed: Swift.Set<String> = []
            /// The request each instance is busy with, by name.
            public var busy: [String: UUID] = [:]
            public var interval: Double = 3
            public var loopRunning = false
            public var lastTick: Date?
            public var lastError: String?
            public init() {}

            public func record(_ name: String) -> ThreadRecord? { threads.first { $0.name == name } }
            public func status(of name: String) -> ThreadStatus { status[name] ?? .stopped(nil) }
            public func isBusy(_ name: String) -> Bool { busy[name] != nil }
            /// Every port the records hold.
            public var takenPorts: Swift.Set<Int> { Swift.Set(threads.flatMap(\.ports)) }
        }

        @Event public var set: Set.Reducer
        @Event public var scan: Scan.Reducer
        @Event public var spawn: Spawn.Reducer
        @Event public var start: Start.Reducer
        @Event public var stop: Stop.Reducer
        @Event public var weave: Weave.Reducer
        @Event public var remove: Remove.Reducer
        @Event public var watch: Watch.Reducer
        @Store public var state: State
        public init() {}
    }
}
