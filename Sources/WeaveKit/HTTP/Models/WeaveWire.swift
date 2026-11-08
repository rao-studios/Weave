//
//  WeaveWire.swift
//  WeaveKit
//
//  What Weave's own port speaks: GET /health, GET /v1/threads, POST /v1/search.
//

import Foundation
import Hummingbird

public struct WeaveHostInfo: Codable, Sendable, Equatable {
    public var kind: String          // "main" | "spawned"
    public var name: String?
    public var sewnHTTP: Int
    public var sewnGRPC: Int
    public var up: Bool

    enum CodingKeys: String, CodingKey {
        case kind, name, up
        case sewnHTTP = "sewn_http"
        case sewnGRPC = "sewn_grpc"
    }

    public init(target: HostTarget, up: Bool) {
        switch target.selection {
        case .main: kind = "main"; name = nil
        case .spawned(let n): kind = "spawned"; name = n
        }
        sewnHTTP = target.sewnPorts.http
        sewnGRPC = target.sewnPorts.grpc
        self.up = up
    }
}

public struct WeaveHealth: ResponseEncodable, Codable, Sendable, Equatable {
    public var status: String
    public var app: String
    public var port: Int
    public var host: WeaveHostInfo?
    public var threads: Int
}

/// One spawned AII, as Weave's port lists it.
public struct WeaveThreadEntry: Codable, Sendable, Equatable {
    public struct Node: Codable, Sendable, Equatable {
        public var threadId: String
        public var isActive: Bool
        public var acceptingStorage: Bool
        enum CodingKeys: String, CodingKey {
            case threadId = "thread_id"
            case isActive = "is_active"
            case acceptingStorage = "accepting_storage"
        }
    }
    /// What a request names this AII by: `thread` in POST /v1/records and POST /v1/search.
    public var id: String
    public var label: String
    public var name: String
    public var home: String
    public var httpPort: Int
    public var grpcPort: Int
    public var status: String
    public var woven: Bool
    public var embedder: String?
    public var documents: Int?
    /// The host's node for this Thread, when the host sees it.
    public var node: Node?
    /// Its Thread is up, so a push into it lands.
    public var accepting: Bool

    enum CodingKeys: String, CodingKey {
        case id, label, name, home, status, woven, embedder, documents, node, accepting
        case httpPort = "http_port"
        case grpcPort = "grpc_port"
    }

    public init(id: String, label: String, home: String, httpPort: Int, grpcPort: Int, status: String, woven: Bool,
                embedder: String?, documents: Int?, node: Node?, accepting: Bool) {
        self.id = id; self.label = label; self.name = id; self.home = home; self.httpPort = httpPort; self.grpcPort = grpcPort
        self.status = status; self.woven = woven; self.embedder = embedder; self.documents = documents; self.node = node
        self.accepting = accepting
    }
}

public struct WeaveThreads: ResponseEncodable, Codable, Sendable, Equatable {
    public var host: WeaveHostInfo?
    /// File deposits under this owner for the host's search to find them.
    public var ownerId: String
    /// Every AII a push can go to: the spawned ones, then the main AII (`main`).
    public var threads: [WeaveThreadEntry]
    /// How to use an entry's `id`.
    public var insert: String = "POST /v1/records {\"thread\": id, \"text\": …}"
    public var search: String = "POST /v1/search {\"query\": …, \"thread\": id (optional: every thread when absent)}"

    public init(host: WeaveHostInfo?, ownerId: String, threads: [WeaveThreadEntry]) {
        self.host = host; self.ownerId = ownerId; self.threads = threads
    }

    enum CodingKeys: String, CodingKey {
        case host, threads, insert, search
        case ownerId = "owner_id"
    }
}

public struct WeaveSearchRequest: Codable, Sendable, Equatable {
    public var query: String
    public var topK: Int?
    /// One AII's id (from GET /v1/threads) to search it alone; absent, the host searches every thread.
    public var thread: String?

    enum CodingKeys: String, CodingKey {
        case query, thread
        case topK = "top_k"
    }

    public init(query: String, topK: Int?, thread: String? = nil) { self.query = query; self.topK = topK; self.thread = thread }
}

public struct WeaveSearchResponse: ResponseEncodable, Codable, Sendable, Equatable {
    public var object: String = "list"
    public var host: WeaveHostInfo?
    public var texts: [String]
    public var references: [PartitionReference]
    public var hits: [SearchHit]
    public var graph: SearchTrace?

    public init(host: WeaveHostInfo?, texts: [String], references: [PartitionReference], hits: [SearchHit], graph: SearchTrace?) {
        self.host = host; self.texts = texts; self.references = references; self.hits = hits; self.graph = graph
    }

    /// One AII's answer in the federated answer's shape, every hit named by that AII.
    public init(_ one: WeaveThreadSearchResponse, thread: String) {
        let references = one.hits.map { PartitionReference(id: $0.documentId, partitionId: $0.partitionId, ownerId: WeaveIdentity.owner, threadId: nil) }
        self.init(host: nil, texts: one.hits.map(\.text), references: references,
                  hits: zip(one.hits, references).map { SearchHit(rank: $0.rank, text: $0.text, reference: $1, threadName: thread) },
                  graph: nil)
    }
}

// MARK: - One AII's records, through Weave's port

/// `POST /v1/threads/{name}/records`: one record (`text`, `name`) or several (`records`), into the
/// AII's group (`group`, a label; Weave's own per-AII group when absent). With `wait` (the default)
/// Weave answers once the records are searchable, so a search right after finds them.
public struct WeavePushRequest: Codable, Sendable, Equatable {
    public struct Record: Codable, Sendable, Equatable {
        public var text: String
        public var name: String?
        public init(text: String, name: String? = nil) { self.text = text; self.name = name }
    }
    /// The AII to file into, by its id from GET /v1/threads (`main` is the main AII). The path names it
    /// instead in POST /v1/threads/{id}/records.
    public var thread: String?
    public var text: String?
    public var name: String?
    public var records: [Record]?
    public var group: String?
    public var wait: Bool?

    public init(thread: String? = nil, text: String? = nil, name: String? = nil, records: [Record]? = nil, group: String? = nil, wait: Bool? = nil) {
        self.thread = thread; self.text = text; self.name = name; self.records = records; self.group = group; self.wait = wait
    }

    /// Every record the request carries, empty texts dropped.
    public var all: [Record] {
        var out = records ?? []
        if let text { out.insert(Record(text: text, name: name), at: 0) }
        return out.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

public struct WeaveGroupRef: Codable, Sendable, Equatable {
    public var id: String
    public var label: String
}

public struct WeavePushResponse: ResponseEncodable, Codable, Sendable, Equatable {
    public var thread: String
    public var ownerId: String
    public var group: WeaveGroupRef
    public var filed: Int
    /// The records are searchable now (false when `wait` was off, or the Thread took longer than Weave waits).
    public var indexed: Bool
    /// Documents in the group after the push.
    public var documents: Int

    enum CodingKeys: String, CodingKey {
        case thread, group, filed, indexed, documents
        case ownerId = "owner_id"
    }
}

/// `POST /v1/threads/{name}/search`.
public struct WeaveThreadSearchRequest: Codable, Sendable, Equatable {
    public var query: String
    public var topK: Int?
    enum CodingKeys: String, CodingKey {
        case query
        case topK = "top_k"
    }
    public init(query: String, topK: Int? = nil) { self.query = query; self.topK = topK }
}

public struct WeaveThreadHit: Codable, Sendable, Equatable {
    public var rank: Int
    public var text: String
    public var documentId: String
    public var partitionId: String
    enum CodingKeys: String, CodingKey {
        case rank, text
        case documentId = "document_id"
        case partitionId = "partition_id"
    }
}

public struct WeaveThreadSearchResponse: ResponseEncodable, Codable, Sendable, Equatable {
    public var thread: String
    public var hits: [WeaveThreadHit]
}

/// `GET /v1/threads/{name}/records`: the AII's groups and documents in Weave's lane.
public struct WeaveRecordsResponse: ResponseEncodable, Codable, Sendable, Equatable {
    public struct Group: Codable, Sendable, Equatable {
        public var id: String
        public var label: String
        public var documents: [LibraryDocument]
    }
    public var thread: String
    public var ownerId: String
    public var groups: [Group]
    enum CodingKeys: String, CodingKey {
        case thread, groups
        case ownerId = "owner_id"
    }
}
