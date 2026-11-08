//
//  SewnModels.swift
//  WeaveKit
//
//  What the host's Sewn answers to a federated search (AII's Sewn/API/Models/Responses/SearchResponse),
//  and the nodes it fans out to (GET /v1/threads, read through AIIClient).
//

import Foundation

public struct SearchTrace: Codable, Sendable, Equatable {
    public var matchedEntityIds: [String]
    public var expansionEdgeIds: [String]
    public var expandedDocuments: Int

    enum CodingKeys: String, CodingKey {
        case matchedEntityIds = "matched_entity_ids"
        case expansionEdgeIds = "expansion_edge_ids"
        case expandedDocuments = "expanded_documents"
    }

    public init(matchedEntityIds: [String], expansionEdgeIds: [String], expandedDocuments: Int) {
        self.matchedEntityIds = matchedEntityIds; self.expansionEdgeIds = expansionEdgeIds; self.expandedDocuments = expandedDocuments
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        matchedEntityIds = try c.decodeIfPresent([String].self, forKey: .matchedEntityIds) ?? []
        expansionEdgeIds = try c.decodeIfPresent([String].self, forKey: .expansionEdgeIds) ?? []
        expandedDocuments = try c.decodeIfPresent(Int.self, forKey: .expandedDocuments) ?? 0
    }
}

public struct SewnSearchResponse: Codable, Sendable, Equatable {
    public var texts: [String]
    public var references: [PartitionReference]
    public var graph: SearchTrace?

    public init(texts: [String], references: [PartitionReference], graph: SearchTrace?) {
        self.texts = texts; self.references = references; self.graph = graph
    }
}

/// One merged hit, with the Weave instance whose Thread answered it when Weave knows it.
public struct SearchHit: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var rank: Int
    public var text: String
    public var reference: PartitionReference
    public var threadName: String?
    public var id: String { "\(rank)/\(reference.partitionId)" }

    public init(rank: Int, text: String, reference: PartitionReference, threadName: String?) {
        self.rank = rank; self.text = text; self.reference = reference; self.threadName = threadName
    }

    enum CodingKeys: String, CodingKey {
        case rank, text, reference
        case threadName = "thread_name"
    }
}

/// A Thread the host's Sewn knows.
public struct HostNode: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var threadId: String
    public var host: String
    public var httpPort: Int
    public var grpcPort: Int
    public var app: String?
    public var isActive: Bool
    public var acceptingStorage: Bool
    public var lastSeen: Date
    public var id: String { threadId }

    public init(threadId: String, host: String, httpPort: Int, grpcPort: Int, app: String?, isActive: Bool,
                acceptingStorage: Bool, lastSeen: Date) {
        self.threadId = threadId; self.host = host; self.httpPort = httpPort; self.grpcPort = grpcPort; self.app = app
        self.isActive = isActive; self.acceptingStorage = acceptingStorage; self.lastSeen = lastSeen
    }

    public init(_ node: AIIThreadNode) {
        self.init(threadId: node.threadId, host: node.host, httpPort: node.httpPort, grpcPort: node.grpcPort, app: node.app,
                  isActive: node.isActive, acceptingStorage: node.acceptingStorage, lastSeen: node.lastSeen)
    }

    enum CodingKeys: String, CodingKey {
        case host, app
        case threadId = "thread_id"
        case httpPort = "http_port"
        case grpcPort = "grpc_port"
        case isActive = "is_active"
        case acceptingStorage = "accepting_storage"
        case lastSeen = "last_seen"
    }
}
