//
//  ThreadModels.swift
//  WeaveKit
//
//  What a Thread's HTTP routes answer, as Weave reads them (AII's Thread/API/Models).
//

import Foundation

/// One document of a group in a Thread's library.
public struct LibraryDocument: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var name: String?
    public var ownerId: String
    public var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case ownerId = "owner_id"
        case createdAt = "created_at"
    }

    public init(id: String, name: String?, ownerId: String, createdAt: Date?) {
        self.id = id; self.name = name; self.ownerId = ownerId; self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        ownerId = try c.decodeIfPresent(String.self, forKey: .ownerId) ?? ""
        createdAt = try? c.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

public struct LibraryGroup: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var label: String
    public var ownerId: String
    public var documents: [LibraryDocument]

    enum CodingKeys: String, CodingKey {
        case id, label, documents
        case ownerId = "owner_id"
    }

    public init(id: String, label: String, ownerId: String, documents: [LibraryDocument]) {
        self.id = id; self.label = label; self.ownerId = ownerId; self.documents = documents
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? id
        ownerId = try c.decodeIfPresent(String.self, forKey: .ownerId) ?? ""
        documents = try c.decodeIfPresent([LibraryDocument].self, forKey: .documents) ?? []
    }
}

struct LibraryResponse: Decodable { let groups: [LibraryGroup] }

public struct GraphEntity: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var kind: String
    public var score: Float
    public var mentionCount: Int
    public var documentIds: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, kind, score
        case mentionCount = "mention_count"
        case documentIds = "document_ids"
    }
}

public struct GraphRelationship: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var subjectId: String
    public var predicate: String
    public var objectId: String
    public var weight: Int

    enum CodingKeys: String, CodingKey {
        case id, predicate, weight
        case subjectId = "subject_id"
        case objectId = "object_id"
    }
}

public struct GraphSnapshot: Codable, Sendable, Equatable {
    public struct Stats: Codable, Sendable, Equatable {
        public var entityCount: Int
        public var relationshipCount: Int
        enum CodingKeys: String, CodingKey {
            case entityCount = "entity_count"
            case relationshipCount = "relationship_count"
        }
    }
    public var entities: [GraphEntity]
    public var relationships: [GraphRelationship]
    public var stats: Stats?

    public init(entities: [GraphEntity], relationships: [GraphRelationship], stats: Stats?) {
        self.entities = entities; self.relationships = relationships; self.stats = stats
    }

    /// The entity's name for an id, for drawing a relationship.
    public func name(of id: String) -> String { entities.first { $0.id == id }?.name ?? id }
}

/// A partition a search found: in a Thread's answer and in a Sewn's merged one.
public struct PartitionReference: Codable, Sendable, Equatable, Hashable {
    public var id: String
    public var partitionId: String
    public var ownerId: String
    public var threadId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case partitionId = "partition_id"
        case ownerId = "owner_id"
        case threadId = "thread_id"
    }

    public init(id: String, partitionId: String, ownerId: String, threadId: String?) {
        self.id = id; self.partitionId = partitionId; self.ownerId = ownerId; self.threadId = threadId
    }
}

/// One Thread's search answer.
public struct ThreadSearchResponse: Codable, Sendable, Equatable {
    public var texts: [String]
    public var references: [PartitionReference]
}

/// One hit in the Explorer's single-Thread search.
public struct ThreadHit: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var text: String
    public var reference: PartitionReference
    public var rank: Int
    public var id: String { "\(rank)/\(reference.partitionId)" }

    public static func zip(_ response: ThreadSearchResponse) -> [ThreadHit] {
        Swift.zip(response.texts, response.references).enumerated().map { ThreadHit(text: $1.0, reference: $1.1, rank: $0 + 1) }
    }
}

/// What a deposit answered.
public struct DepositReceipt: Codable, Sendable, Equatable {
    public var success: Bool
    public var model: String?
}
