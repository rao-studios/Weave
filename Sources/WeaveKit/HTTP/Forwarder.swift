//
//  Forwarder.swift
//  WeaveKit
//
//  Weave's port is a forwarder, not an API of its own. A request carries exactly the body an AII's
//  Thread (or the host's Sewn) takes, on the same path, plus Weave's routing spec, which Weave strips:
//
//      "weave": {"aii": "alpha", "wait": true}
//
//    aii    which AII's Thread to forward to: an id from GET /v1/threads (`main` is the main AII).
//           Also accepted as the X-Weave-AII header or the ?aii= query. POST /v1/search without it
//           goes to the host's Sewn instead: one search across every woven AII.
//    wait   POST /v1/batch/embeddings only: answer once each filed text is searchable (Thread files
//           it a moment after it answers), so a search right after finds it.
//
//  Weave adds the AII's key and, where a body leaves it out, the owner (`local-weave`, the owner a
//  search across every AII answers for). It answers with the AII's own status and body; on success
//  the body gains a `weave` object saying what Weave did. Porting to a direct request: drop `weave`,
//  send the same body to the AII's Thread (its `direct` URL in GET /v1/threads) with its key.
//

import Foundation

/// Where one forwarded request goes: an AII's Thread or the host's Sewn, and the key it wants.
public struct ForwardTarget: Sendable, Equatable {
    public let aii: String?
    public let port: Int
    public let secret: String

    public init(aii: String?, port: Int, secret: String) {
        self.aii = aii; self.port = port; self.secret = secret
    }
}

public enum Forwarder {
    /// The Thread routes Weave forwards to an AII, as the Thread names them.
    public static let threadRoutes: [(method: String, path: String)] = [
        ("POST", "/v1/batch/embeddings"),
        ("POST", "/v1/search"),
        ("POST", "/v1/library"),
        ("POST", "/v1/graph"),
        ("GET", "/v1/stats"),
    ]

    /// Weave's routing spec, as it was found on a request.
    public struct Routing: Sendable, Equatable {
        public var aii: String?
        public var wait: Bool
        public init(aii: String? = nil, wait: Bool = false) { self.aii = aii; self.wait = wait }
    }

    public enum Failure: Error, Equatable {
        case badBody(String)
        case noRoute(String)
    }

    /// The routing spec and the AII's own body. A header or query `aii` wins over the body's.
    public static func split(_ body: Data?, header: String?, query: String?) throws -> (Routing, [String: Any]?) {
        var routing = Routing()
        var object: [String: Any]?
        if let body, !body.isEmpty {
            guard let parsed = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                throw Failure.badBody("the body must be a JSON object: the AII's own request, plus \"weave\": {\"aii\": …}")
            }
            object = parsed
            if let spec = parsed["weave"] as? [String: Any] {
                routing.aii = (spec["aii"] as? String).flatMap(clean)
                routing.wait = spec["wait"] as? Bool ?? false
                object?.removeValue(forKey: "weave")
            }
        }
        if let query = query.flatMap(clean) { routing.aii = query }
        if let header = header.flatMap(clean) { routing.aii = header }
        return (routing, object)
    }

    /// Fills the owner a Thread body leaves out, where that path's body names one. Answers the owner
    /// the request files or reads as.
    @discardableResult
    public static func fillOwner(_ body: inout [String: Any], path: String) -> String {
        switch path {
        case "/v1/library":
            let owner = body["owner_id"] as? String ?? WeaveIdentity.owner
            body["owner_id"] = owner
            return owner
        case "/v1/batch/embeddings", "/v1/search", "/v1/graph":
            var thread = body["thread"] as? [String: Any] ?? [:]
            let owner = thread["owner_id"] as? String ?? WeaveIdentity.owner
            thread["owner_id"] = owner
            if var group = thread["group"] as? [String: Any] {
                if group["owner_id"] == nil { group["owner_id"] = owner }
                thread["group"] = group
            }
            if path == "/v1/search", thread["scope"] == nil { thread["scope"] = "global" }
            body["thread"] = thread
            return owner
        default:
            return WeaveIdentity.owner
        }
    }

    /// Fills Sewn's owner for a search across every AII; a plain {query, top_k} is accepted too.
    public static func fillSewn(_ body: inout [String: Any]) {
        var sewn = body["sewn"] as? [String: Any] ?? [:]
        if sewn["owner_id"] == nil { sewn["owner_id"] = WeaveIdentity.owner }
        if sewn["scope"] == nil { sewn["scope"] = "global" }
        body["sewn"] = sewn
    }

    /// The texts a Thread insert files: each input is a string or an array of strings.
    public static func inputs(_ body: [String: Any]) -> [String] {
        (body["inputs"] as? [Any] ?? []).compactMap { input in
            if let text = input as? String { return text }
            return (input as? [String])?.joined(separator: " ")
        }
    }

    /// Adds Weave's `weave` object to a JSON object answer; anything else is passed as it came.
    public static func annotate(_ data: Data, with weave: [String: Any]) -> Data {
        guard var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return data }
        object["weave"] = weave
        return (try? JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes])) ?? data
    }

    public static func encode(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes])) ?? Data("{}".utf8)
    }

    /// Sends a body to a target and answers its bytes and status.
    public static func send(method: String, path: String, body: Data?, to target: ForwardTarget,
                            transport: ThreadHTTPClient.Transport = LoopbackHTTP.send, timeout: TimeInterval = 180) async throws -> (Data, Int) {
        let request = LoopbackHTTP.request(port: target.port, path: path, method: method, body: body, secret: target.secret, timeout: timeout)
        return try await transport(request)
    }

    /// Whether a search of the target finds each text (its first words, as Thread stores the first chunk).
    public static func searchable(_ texts: [String], owner: String, target: ForwardTarget,
                                  transport: @escaping ThreadHTTPClient.Transport = LoopbackHTTP.send) async throws -> Bool {
        let client = ThreadHTTPClient(port: target.port, secret: target.secret, transport: transport)
        for text in texts.prefix(5) {
            let head = normalized(String(text.prefix(48)))
            let found = try await client.search(String(text.prefix(300)), ownerId: owner, topK: 5).texts
            guard found.contains(where: { normalized($0).contains(head) }) else { return false }
        }
        return true
    }

    /// Waits up to `seconds` for every text to be searchable.
    public static func waitUntilSearchable(_ texts: [String], owner: String, target: ForwardTarget, seconds: Double = 60,
                                           transport: @escaping ThreadHTTPClient.Transport = LoopbackHTTP.send) async -> Bool {
        guard !texts.isEmpty else { return true }
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if (try? await searchable(texts, owner: owner, target: target, transport: transport)) == true { return true }
            try? await TaskSleep.seconds(0.25)
        }
        return false
    }

    static func normalized(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func clean(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
