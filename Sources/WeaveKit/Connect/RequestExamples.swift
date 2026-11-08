//
//  RequestExamples.swift
//  WeaveKit
//
//  The requests another app makes to Weave's port, written out to copy: list the AIIs (each entry's
//  `id` is what an insert names), file a record into one, search one, search every one, list one's
//  records. In curl, Swift and JavaScript, and a whole client (a small network service) for Swift
//  and JavaScript. Each reads Weave's key from ~/.rao/secrets/weave when the port asks for it.
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

public struct RequestExample: Sendable, Equatable, Identifiable {
    public enum Kind: String, Sendable, CaseIterable { case threads, insert, searchOne, searchAll, records }
    public let kind: Kind
    public let title: String
    public let detail: String
    public let method: String
    public let path: String
    /// The JSON body, compact, as it is sent.
    public let body: String?
    public var id: String { kind.rawValue }
}

public enum RequestExamples {
    public static let sampleText = "The Jacquard loom reads a chain of punched cards; each card lifts the warp threads for one pass."
    public static let sampleQuery = "punched cards"

    public static func all(thread: String) -> [RequestExample] {
        [
            RequestExample(kind: .threads, title: "See the AIIs you can file into",
                           detail: "Each entry's id goes in \"thread\". accepting is true while its Thread is up; main is the main AII.",
                           method: "GET", path: "/v1/threads", body: nil),
            RequestExample(kind: .insert, title: "File a record into an AII",
                           detail: "Weave answers once the record is searchable (indexed: true), so a search right after finds it. Send records: [{text, name}] for several.",
                           method: "POST", path: "/v1/records",
                           body: json(["thread": thread, "text": sampleText, "name": "loom-note", "group": "Notes"])),
            RequestExample(kind: .searchOne, title: "Search that AII alone",
                           detail: "The same answer shape as a federated search, every hit from that AII.",
                           method: "POST", path: "/v1/search", body: json(["query": sampleQuery, "thread": thread, "top_k": 5])),
            RequestExample(kind: .searchAll, title: "Search every AII at once",
                           detail: "The host fans the query out to every woven Thread and merges by score; each hit says which AII held it.",
                           method: "POST", path: "/v1/search", body: json(["query": sampleQuery, "top_k": 10])),
            RequestExample(kind: .records, title: "List an AII's records",
                           detail: "Its groups and documents in Weave's lane.",
                           method: "GET", path: "/v1/threads/\(thread)/records", body: nil),
        ]
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
        let thread = threadIn(example) ?? "alpha"
        switch example.kind {
        case .threads:
            return """
            let weave = WeaveService()
            for thread in try await weave.threads() where thread.accepting {
                print(thread.id, thread.label)
            }
            """
        case .insert:
            return """
            let receipt = try await WeaveService().insert(
                "\(sampleText)",
                into: "\(thread)", name: "loom-note", group: "Notes")
            print(receipt.indexed ? "searchable now" : "indexing", receipt.documents)
            """
        case .searchOne:
            return """
            let hits = try await WeaveService().search("\(sampleQuery)", in: "\(thread)", topK: 5)
            hits.forEach { print($0.rank, $0.text) }
            """
        case .searchAll:
            return """
            let hits = try await WeaveService().search("\(sampleQuery)")
            hits.forEach { print($0.rank, $0.threadName ?? "?", $0.text) }
            """
        case .records:
            return """
            for group in try await WeaveService().records(in: "\(thread)") {
                print(group.label, group.documents.count)
            }
            """
        }
    }

    static func javascriptCall(_ example: RequestExample) -> String {
        let thread = threadIn(example) ?? "alpha"
        switch example.kind {
        case .threads:
            return """
            const { threads } = await weave("GET", "/v1/threads");
            console.log(threads.filter((t) => t.accepting).map((t) => [t.id, t.label]));
            """
        case .insert:
            return """
            const receipt = await weave("POST", "/v1/records", {
              thread: "\(thread)",
              text: "\(sampleText)",
              name: "loom-note",
              group: "Notes",
            });
            console.log(receipt.indexed, receipt.documents);
            """
        case .searchOne:
            return """
            const { hits } = await weave("POST", "/v1/search", { query: "\(sampleQuery)", thread: "\(thread)", top_k: 5 });
            hits.forEach((h) => console.log(h.rank, h.text));
            """
        case .searchAll:
            return """
            const { hits } = await weave("POST", "/v1/search", { query: "\(sampleQuery)", top_k: 10 });
            hits.forEach((h) => console.log(h.rank, h.thread_name, h.text));
            """
        case .records:
            return """
            const { groups } = await weave("GET", "/v1/threads/\(thread)/records");
            groups.forEach((g) => console.log(g.label, g.documents.length));
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

        /// Weave on this Mac: its AIIs, records filed into one, searches of one or all of them.
        final class WeaveService {
            struct Thread: Decodable { let id: String; let label: String; let status: String; let accepting: Bool }
            struct Receipt: Decodable { let thread: String; let filed: Int; let indexed: Bool; let documents: Int }
            struct Hit: Decodable {
                let rank: Int
                let text: String
                let threadName: String?
                enum CodingKeys: String, CodingKey { case rank, text, threadName = "thread_name" }
            }
            struct Group: Decodable {
                struct Document: Decodable { let id: String; let name: String? }
                let id: String
                let label: String
                let documents: [Document]
            }

            let base: URL
            let key: String?

            init(port: Int = \(port)) {
                base = URL(string: "http://127.0.0.1:\\(port)")!\(key)
            }

            func threads() async throws -> [Thread] {
                struct Answer: Decodable { let threads: [Thread] }
                return try await call("GET", "/v1/threads", nil, as: Answer.self).threads
            }

            func insert(_ text: String, into thread: String, name: String? = nil, group: String? = nil) async throws -> Receipt {
                var body: [String: Any] = ["thread": thread, "text": text]
                if let name { body["name"] = name }
                if let group { body["group"] = group }
                return try await call("POST", "/v1/records", body, as: Receipt.self)
            }

            func search(_ query: String, in thread: String? = nil, topK: Int = 10) async throws -> [Hit] {
                struct Answer: Decodable { let hits: [Hit] }
                var body: [String: Any] = ["query": query, "top_k": topK]
                if let thread { body["thread"] = thread }
                return try await call("POST", "/v1/search", body, as: Answer.self).hits
            }

            func records(in thread: String) async throws -> [Group] {
                struct Answer: Decodable { let groups: [Group] }
                return try await call("GET", "/v1/threads/\\(thread)/records", nil, as: Answer.self).groups
            }

            private func call<T: Decodable>(_ method: String, _ path: String, _ body: [String: Any]?, as type: T.Type) async throws -> T {
                var request = URLRequest(url: base.appendingPathComponent(path))
                request.httpMethod = method
                if let key { request.setValue(key, forHTTPHeaderField: "X-Ambient-Secret") }
                if let body {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                }
                let (data, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard status == 200 else {
                    throw NSError(domain: "Weave", code: status,
                                  userInfo: [NSLocalizedDescriptionKey: String(decoding: data, as: UTF8.self)])
                }
                return try JSONDecoder().decode(T.self, from: data)
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
        // Weave on this Mac: its AIIs, records filed into one, searches of one or all of them (Node 18+).
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

    // MARK: - Pieces

    private static func json(_ object: [String: Any]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
        // Keys in reading order rather than sorted: thread first, then what is filed or asked.
        let order = ["thread", "query", "text", "name", "group", "top_k"]
        guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return String(decoding: data, as: UTF8.self) }
        let parts = order.compactMap { key -> String? in
            guard let value = parsed[key] else { return nil }
            let encoded = (try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .withoutEscapingSlashes]))
                .map { String(decoding: $0, as: UTF8.self) } ?? "null"
            return "\"\(key)\": \(encoded)"
        }
        return "{" + parts.joined(separator: ", ") + "}"
    }

    private static func threadIn(_ example: RequestExample) -> String? {
        guard let body = example.body?.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return example.kind == .records ? example.path.split(separator: "/").dropFirst(2).first.map(String.init) : nil
        }
        return object["thread"] as? String
    }
}
