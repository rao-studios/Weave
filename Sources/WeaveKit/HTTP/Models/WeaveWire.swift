//
//  WeaveWire.swift
//  WeaveKit
//
//  What Weave's own two routes answer: GET /health and GET /v1/threads. Everything else on the port
//  is an AII's own API, forwarded (Forwarder.swift).
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
    /// What a request names this AII by: `"weave": {"aii": id}`, the X-Weave-AII header, or `?aii=`.
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
    /// Its Thread is up, so a request routed to it lands.
    public var accepting: Bool
    /// Where a request goes without Weave: the Thread's URL and the file holding the key it wants.
    public var direct: Direct

    public struct Direct: Codable, Sendable, Equatable {
        public var url: String
        public var keyFile: String
        enum CodingKeys: String, CodingKey {
            case url
            case keyFile = "key_file"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, label, name, home, status, woven, embedder, documents, node, accepting, direct
        case httpPort = "http_port"
        case grpcPort = "grpc_port"
    }

    public init(id: String, label: String, home: String, httpPort: Int, grpcPort: Int, status: String, woven: Bool,
                embedder: String?, documents: Int?, node: Node?, accepting: Bool) {
        self.id = id; self.label = label; self.name = id; self.home = home; self.httpPort = httpPort; self.grpcPort = grpcPort
        self.status = status; self.woven = woven; self.embedder = embedder; self.documents = documents; self.node = node
        self.accepting = accepting
        let aiiHome = AIIHome(root: URL(fileURLWithPath: home, isDirectory: true))
        self.direct = Direct(url: "http://127.0.0.1:\(httpPort)", keyFile: PrivateFile.path(aiiHome.secretFile(for: WeaveIdentity.app)))
    }
}

public struct WeaveThreads: ResponseEncodable, Codable, Sendable, Equatable {
    public var host: WeaveHostInfo?
    /// File deposits under this owner for the host's search to find them.
    public var ownerId: String
    /// Every AII a push can go to: the spawned ones, then the main AII (`main`).
    public var threads: [WeaveThreadEntry]
    /// How a request routes to an entry: its own Thread body, plus this.
    public var routing: String = "\"weave\": {\"aii\": id, \"wait\": true}  (or X-Weave-AII: id, or ?aii=id)"
    /// The Thread routes the port forwards; POST /v1/search with no AII goes to the host's Sewn.
    public var forwards: [String] = Forwarder.threadRoutes.map { "\($0.method) \($0.path)" }

    public init(host: WeaveHostInfo?, ownerId: String, threads: [WeaveThreadEntry]) {
        self.host = host; self.ownerId = ownerId; self.threads = threads
    }

    enum CodingKeys: String, CodingKey {
        case host, threads, routing, forwards
        case ownerId = "owner_id"
    }
}
