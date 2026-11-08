//
//  RequestExamples.swift
//  WeaveKit
//
//  The requests another app makes to Weave's port, written out to copy. Each body is the AII's own
//  (Thread's insert, search, library and graph bodies; Sewn's search body for a search across every
//  AII) plus Weave's routing spec, `"weave": {"aii": …, "wait": …}`. Each example also says its
//  direct form: the same body without `weave`, to the AII's Thread with that AII's key. In curl,
//  Swift and JavaScript, with a whole thin client for Swift and JavaScript.
//

import Foundation

public enum RequestFormat: String, CaseIterable, Sendable, Hashable, Identifiable {
    case curl, swift, javascript
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .curl: return "curl"
        case .swift: return "Swift"
        case .javascript: return "JavaScript"
        }
    }
}

/// A JSON value with its keys kept in the order they are written, so a body reads as the AII's
/// documentation lays it out.
public indirect enum JSONValue: Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([(String, JSONValue)])

    public static func == (a: JSONValue, b: JSONValue) -> Bool { a.json == b.json }

    public var json: String {
        switch self {
        case .string(let s): return Self.quote(s)
        case .number(let n): return n == n.rounded() ? String(Int(n)) : String(n)
        case .bool(let b): return b ? "true" : "false"
        case .array(let items): return "[" + items.map(\.json).joined(separator: ", ") + "]"
        case .object(let pairs): return "{" + pairs.map { "\(Self.quote($0.0)): \($0.1.json)" }.joined(separator: ", ") + "}"
        }
    }

    /// The same value as a Swift literal (`[String: Any]` for an object).
    public var swift: String {
        switch self {
        case .object(let pairs) where pairs.isEmpty: return "[:]"
        case .object(let pairs): return "[" + pairs.map { "\(Self.quote($0.0)): \($0.1.swift)" }.joined(separator: ", ") + "]"
        case .array(let items): return "[" + items.map(\.swift).joined(separator: ", ") + "]"
        default: return json
        }
    }

    static func quote(_ s: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: s, options: [.fragmentsAllowed, .withoutEscapingSlashes])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}

public struct RequestExample: Sendable, Equatable, Identifiable {
    public enum Kind: String, Sendable, CaseIterable { case threads, insert, searchOne, searchAll, library, graph }
    public let kind: Kind
    public let title: String
    public let detail: String
    public let method: String
    public let path: String
    /// The AII the request routes to (nil: Weave's own route, or the host's Sewn).
    public let aii: String?
    /// `weave.wait`: a Thread insert answers once searchable.
    public let wait: Bool
    /// The AII's own body, as it would go to the AII directly.
    public let own: JSONValue?
    /// Whether this request has a direct form: an AII's Thread route, not Weave's own nor the host's.
    public var direct: Bool { aii != nil }
    public var id: String { kind.rawValue }

    /// The body Weave's port takes: the routing spec, then the AII's own body.
    public var body: String? {
        guard case .object(let pairs)? = own else { return nil }
        guard let aii else { return own?.json }
        var spec: [(String, JSONValue)] = [("aii", .string(aii))]
        if wait { spec.append(("wait", .bool(true))) }
        return JSONValue.object([("weave", .object(spec))] + pairs).json
    }
}

public enum RequestExamples {
    public static let sampleText = "The Jacquard loom reads a chain of punched cards; each card lifts the warp threads for one pass."
    public static let sampleQuery = "punched cards"
    static let owner = JSONValue.string(WeaveIdentity.owner)

    public static func all(thread: String) -> [RequestExample] {
        [
            RequestExample(kind: .threads, title: "See the AIIs a request can route to",
                           detail: "Each entry's id goes in \"weave\": {\"aii\": id}; main is the main AII. direct is its Thread's own URL and key file.",
                           method: "GET", path: "/v1/threads", aii: nil, wait: false, own: nil),
            RequestExample(kind: .insert, title: "File records into an AII",
                           detail: "Thread's own insert body; entities, relationships, tags, metadata and media_type pass through untouched. Entities you name are in the graph at once, and a search that matches an entity looks among the records that carry it; the on-device extractor adds more as it reads. With wait, Weave answers once every input is searchable.",
                           method: "POST", path: "/v1/batch/embeddings", aii: thread, wait: true,
                           own: .object([
                            ("inputs", .array([.string(sampleText)])),
                            ("names", .array([.string("loom-note")])),
                            ("sanitize", .bool(true)),
                            ("thread", .object([("owner_id", owner),
                                                ("group", .object([("id", .string("notes")), ("label", .string("Notes")), ("owner_id", owner)]))])),
                            ("entities", .array([.array([.object([("name", .string("Jacquard loom")), ("kind", .string("machine"))]),
                                                         .object([("name", .string("punched cards")), ("kind", .string("concept"))])])])),
                           ])),
            RequestExample(kind: .searchOne, title: "Search that AII alone",
                           detail: "Thread's own search body: filter by group, groups, entities, aggregate or media_type in thread.",
                           method: "POST", path: "/v1/search", aii: thread, wait: false,
                           own: .object([("query", .string(sampleQuery)),
                                         ("thread", .object([("owner_id", owner), ("scope", .string("global")), ("top_k", .number(5))]))])),
            RequestExample(kind: .searchAll, title: "Search every AII at once",
                           detail: "No aii: Sewn's own search body, to the host, which fans out to every woven AII and merges by score. weave.threads names the AII behind each thread_id.",
                           method: "POST", path: "/v1/search", aii: nil, wait: false,
                           own: .object([("query", .string(sampleQuery)), ("top_k", .number(10)),
                                         ("sewn", .object([("owner_id", owner), ("scope", .string("global"))]))])),
            RequestExample(kind: .library, title: "List an AII's records",
                           detail: "Thread's own library body: its groups and their documents.",
                           method: "POST", path: "/v1/library", aii: thread, wait: false,
                           own: .object([("owner_id", owner), ("include_available", .bool(true))])),
            RequestExample(kind: .graph, title: "Walk an AII's graph",
                           detail: "Thread's own graph body: the entities and relationships it extracted on device, near a query or an entity.",
                           method: "POST", path: "/v1/graph", aii: thread, wait: false,
                           own: .object([("thread", .object([("owner_id", owner)])), ("query", .string("looms")),
                                         ("hops", .number(1)), ("limit", .number(20))])),
        ]
    }

    /// The direct form of an example, for the AII's Thread at `url` with the key in `keyFile`.
    public static func direct(_ example: RequestExample, url: String, keyFile: String) -> String? {
        guard example.direct else { return nil }
        return "Direct, without Weave: \(example.method) \(url)\(example.path) with X-Ambient-Secret from \(keyFile), the same body without \"weave\"."
    }

    // MARK: - Code

    public static func code(_ example: RequestExample, format: RequestFormat, port: Int, requireSecret: Bool) -> String {
        switch format {
        case .curl: return curl(example, port: port, requireSecret: requireSecret)
        case .swift: return swiftCall(example)
        case .javascript: return javascriptCall(example)
        }
    }

    static func curl(_ example: RequestExample, port: Int, requireSecret: Bool) -> String {
        var lines = ["curl -s\(example.method == "GET" ? "" : " -X \(example.method)") http://127.0.0.1:\(port)\(example.path)"]
        if requireSecret { lines.append("  -H \"X-Ambient-Secret: $(cat ~/.rao/secrets/weave)\"") }
        if let body = example.body {
            lines.append("  -H 'Content-Type: application/json'")
            lines.append("  -d '\(body.replacingOccurrences(of: "'", with: "'\\''"))'")
        }
        return lines.joined(separator: " \\\n")
    }

    static func swiftCall(_ example: RequestExample) -> String {
        let route = example.aii.map { "aii: \(JSONValue.quote($0)), " } ?? ""
        let wait = example.wait ? "wait: true, " : ""
        switch example.kind {
        case .threads:
            return """
            for thread in try await WeaveService().threads() where thread.accepting {
                print(thread.id, thread.label, thread.direct.url)
            }
            """
        default:
            return """
            let answer = try await WeaveService().post("\(example.path)", \(route)\(wait)body: \(example.own?.swift ?? "[:]"))
            print(answer)
            """
        }
    }

    static func javascriptCall(_ example: RequestExample) -> String {
        switch example.kind {
        case .threads:
            return """
            const { threads } = await weave("GET", "/v1/threads");
            console.log(threads.filter((t) => t.accepting).map((t) => [t.id, t.label, t.direct.url]));
            """
        default:
            return """
            const answer = await weave("\(example.method)", "\(example.path)", \(example.body ?? "undefined"));
            console.log(JSON.stringify(answer));
            """
        }
    }

    // MARK: - The client

    /// A whole client to paste into another app: nil for curl.
    public static func client(format: RequestFormat, port: Int, requireSecret: Bool) -> String? {
        switch format {
        case .curl: return nil
        case .swift: return swiftClient(port: port, requireSecret: requireSecret)
        case .javascript: return javascriptClient(port: port, requireSecret: requireSecret)
        }
    }

    static func swiftClient(port: Int, requireSecret: Bool) -> String {
        let key = requireSecret ? """

                // Weave's key. A sandboxed app cannot read ~/.rao: turn off "Require Weave's secret" in
                // Weave › Settings, or pass the key in.
                let file = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".rao/secrets/weave")
                key = (try? String(contentsOf: file, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
            """ : "\n        key = nil"
        return """
        import Foundation

        /// Weave on this Mac, as a forwarder: each call is an AII's own request (Thread's insert,
        /// search, library and graph; Sewn's search across every AII), routed by `aii`. To go to an
        /// AII directly later, send the same body to its `direct.url` with the key in its `direct.key_file`.
        final class WeaveService {
            struct Thread: Decodable {
                struct Direct: Decodable {
                    let url: String
                    let keyFile: String
                    enum CodingKeys: String, CodingKey { case url, keyFile = "key_file" }
                }
                let id: String
                let label: String
                let status: String
                let accepting: Bool
                let direct: Direct
            }

            let base: URL
            let key: String?

            init(port: Int = \(port)) {
                base = URL(string: "http://127.0.0.1:\\(port)")!\(key)
            }

            /// The AIIs a request can route to.
            func threads() async throws -> [Thread] {
                struct Answer: Decodable { let threads: [Thread] }
                let (data, _) = try await send("GET", "/v1/threads", nil)
                return try JSONDecoder().decode(Answer.self, from: data).threads
            }

            /// An AII's own request, forwarded: `body` is exactly what the AII takes on `path`.
            /// `aii` routes it (nil: a search across every AII); `wait` holds an insert until searchable.
            func post(_ path: String, aii: String? = nil, wait: Bool = false, body: [String: Any]) async throws -> [String: Any] {
                var routed = body
                if let aii { routed["weave"] = ["aii": aii, "wait": wait] }
                let (data, _) = try await send("POST", path, try JSONSerialization.data(withJSONObject: routed))
                return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            }

            private func send(_ method: String, _ path: String, _ body: Data?) async throws -> (Data, Int) {
                var request = URLRequest(url: base.appendingPathComponent(path))
                request.httpMethod = method
                if let key { request.setValue(key, forHTTPHeaderField: "X-Ambient-Secret") }
                if let body {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = body
                }
                let (data, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard (200..<300).contains(status) else {
                    throw NSError(domain: "Weave", code: status,
                                  userInfo: [NSLocalizedDescriptionKey: String(decoding: data, as: UTF8.self)])
                }
                return (data, status)
            }
        }
        """
    }

    static func javascriptClient(port: Int, requireSecret: Bool) -> String {
        let key = requireSecret ? """
        import { readFileSync } from "node:fs";
        import { homedir } from "node:os";

        // Weave's key, read where Weave keeps it.
        const key = readFileSync(`${homedir()}/.rao/secrets/weave`, "utf8").trim();

        """ : "const key = null;\n\n"
        return """
        // Weave on this Mac, as a forwarder (Node 18+): each call is an AII's own request plus
        // "weave": {"aii": id}. To go to an AII directly later, drop "weave" and send the same body
        // to its direct.url with the key in its direct.key_file.
        \(key)const base = "http://127.0.0.1:\(port)";

        export async function weave(method, path, body) {
          const headers = {};
          if (key) headers["X-Ambient-Secret"] = key;
          if (body) headers["Content-Type"] = "application/json";
          const response = await fetch(base + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
          if (!response.ok) throw new Error(`${response.status} ${await response.text()}`);
          return response.json();
        }
        """
    }
}
