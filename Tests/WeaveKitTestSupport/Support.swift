//
//  Support.swift
//  WeaveKitTestSupport
//
//  Scratch AII homes, fixture records and a stub transport: test doubles, in no product.
//

import Foundation
import WeaveKit

/// A scratch folder holding a main AII home (`rao`) and a fabric root (`fabric`), removed by `clean()`.
public struct Scratch: Sendable {
    public let url: URL
    public var main: AIIHome { AIIHome(root: url.appendingPathComponent("rao", isDirectory: true)) }
    public var root: URL { url.appendingPathComponent("fabric", isDirectory: true) }

    public init(_ label: String = "weave-tests") {
        url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(label)-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func clean() { try? FileManager.default.removeItem(at: url) }
}

public enum Fixtures {
    public static func record(_ name: String, slot: Int = 1, home: String? = nil, woven: Bool = true, backend: String = "mlx") -> ThreadRecord {
        ThreadRecord(name: name, home: home ?? "/tmp/weave-fixture/\(name)", createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                     slot: WeavePortPlan.slot(slot), graphBackend: backend, woven: woven)
    }

    public static func node(_ id: String, httpPort: Int, app: String? = "weave", active: Bool = true) -> HostNode {
        HostNode(threadId: id, host: "127.0.0.1", httpPort: httpPort, grpcPort: httpPort + 1, app: app, isActive: active,
                 acceptingStorage: true, lastSeen: Date())
    }

    public static let sewnSearchJSON = """
    {"object":"list","texts":["alpha knows the loom","beta knows the shuttle"],
     "references":[{"id":"d1","partition_id":"p1","owner_id":"local-weave","thread_id":"AAA"},
                   {"id":"d2","partition_id":"p2","owner_id":"local-weave","thread_id":"bbb"}],
     "graph":{"matched_entity_ids":["e1"],"expansion_edge_ids":[],"expanded_documents":2},
     "contribution":null}
    """

    public static let libraryJSON = """
    {"groups":[{"id":"weave-alpha","label":"Weave · alpha","owner_id":"local-weave",
      "documents":[{"id":"d1","url":"file:///x","owner_id":"local-weave","name":"note","created_at":"2026-11-07T10:00:00Z"},
                   {"id":"d2","url":"file:///y","owner_id":"local-weave","created_at":784000000}]}]}
    """
}

/// Answers every request with one status and body, recording what was asked.
public final class StubTransport: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []
    public let status: Int
    public let body: Data

    public init(status: Int = 200, body: String) {
        self.status = status
        self.body = Data(body.utf8)
    }

    public var asked: [URLRequest] { lock.withLock { requests } }

    public var transport: ThreadHTTPClient.Transport {
        { [self] request in
            lock.withLock { requests.append(request) }
            return (body, status)
        }
    }
}
