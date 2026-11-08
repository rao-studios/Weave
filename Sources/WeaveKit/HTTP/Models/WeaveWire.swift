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

    enum CodingKeys: String, CodingKey {
        case name, home, status, woven, embedder, documents, node
        case httpPort = "http_port"
        case grpcPort = "grpc_port"
    }

    public init(name: String, home: String, httpPort: Int, grpcPort: Int, status: String, woven: Bool,
                embedder: String?, documents: Int?, node: Node?) {
        self.name = name; self.home = home; self.httpPort = httpPort; self.grpcPort = grpcPort; self.status = status
        self.woven = woven; self.embedder = embedder; self.documents = documents; self.node = node
    }
}

public struct WeaveThreads: ResponseEncodable, Codable, Sendable, Equatable {
    public var host: WeaveHostInfo?
    /// File deposits under this owner for the host's search to find them.
    public var ownerId: String
    public var threads: [WeaveThreadEntry]

    enum CodingKeys: String, CodingKey {
        case host, threads
        case ownerId = "owner_id"
    }
}

public struct WeaveSearchRequest: Codable, Sendable, Equatable {
    public var query: String
    public var topK: Int?

    enum CodingKeys: String, CodingKey {
        case query
        case topK = "top_k"
    }

    public init(query: String, topK: Int?) { self.query = query; self.topK = topK }
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
}
