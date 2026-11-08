//
//  FabricModels.swift
//  WeaveKit
//

import Foundation

/// A spawned AII's Thread process, as the last probe found it.
public enum ThreadStatus: Sendable, Equatable, Hashable {
    case stopped(String?)
    case starting
    case up(pid: Int32)
    case unhealthy(String)

    public var isUp: Bool { if case .up = self { return true }; return false }
    public var isRunning: Bool {
        switch self {
        case .up, .starting: return true
        default: return false
        }
    }

    public var label: String {
        switch self {
        case .stopped: return "stopped"
        case .starting: return "starting"
        case .up: return "up"
        case .unhealthy: return "unhealthy"
        }
    }

    public var detail: String? {
        switch self {
        case .stopped(let detail): return detail
        case .starting: return "waiting for /health"
        case .up(let pid): return "pid \(pid)"
        case .unhealthy(let reason): return reason
        }
    }
}

/// One Thread's counts in Weave's lane.
public struct ThreadCounts: Sendable, Equatable, Hashable {
    public var documents: Int
    public var groups: Int
    public var entities: Int
    public var relationships: Int

    public init(documents: Int, groups: Int, entities: Int, relationships: Int) {
        self.documents = documents; self.groups = groups; self.entities = entities; self.relationships = relationships
    }

    public init(_ stats: AIIStats) {
        self.init(documents: stats.documents, groups: stats.groups, entities: stats.entities, relationships: stats.relationships)
    }
}

/// What one probe of one Thread found.
public struct ThreadProbe: Sendable, Equatable {
    public var status: ThreadStatus
    public var embedder: ThreadEmbedderState?
    public var extractor: String?
    public var counts: ThreadCounts?
}

/// What a scan of the fabric's folder found.
public struct FabricScan: Sendable, Equatable {
    public var root: String
    public var fingerprint: String
    public var records: [ThreadRecord]
    public var shapes: [String: LaunchShape]
    public var reseed: Set<String>
    public var serverBinary: String
    public var serverInstalled: Bool
    public var legacyNote: String?
}

extension FabricService {
    /// The typed replies of the ticketed entries.
    public enum Reply: Sendable {
        case scan(FabricScan)
        case record(ThreadRecord)
        case status(ThreadStatus)
        case done
    }
}
