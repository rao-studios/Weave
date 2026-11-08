//
//  ThreadGateway.swift
//  WeaveKit
//
//  What Weave's port does for another app with one AII, by name ("main" is the main AII's Thread):
//  push records, search, list. Weave fills in what the AII asks for (its secret, Weave's owner, the
//  group) so the caller needs only Weave's port. A push waits until the new records are searchable:
//  Thread answers a deposit at once and indexes it a moment later.
//

import Foundation

public enum ThreadGateway {
    /// The name that reaches the main AII's Thread.
    public static let mainName = "main"

    public static func ref(_ name: String) -> ThreadRef { name == mainName ? .main : .spawned(name) }

    /// The group a push files into: Weave's own per-AII group, or one named by the caller's label.
    public static func group(thread: String, label: String?) -> WeaveGroupRef {
        guard let label = label?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty else {
            let own = ExplorerOps.depositGroup(ref(thread))
            return WeaveGroupRef(id: own.id, label: own.label)
        }
        let slug = label.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
            .reduce(into: "") { out, c in if !(c == "-" && out.hasSuffix("-")) { out.append(c) } }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return WeaveGroupRef(id: "weave-\(thread)-\(slug.isEmpty ? "group" : slug)", label: label)
    }

    public static func push(_ request: WeavePushRequest, thread: String, endpoint: ExplorerOps.Endpoint,
                            waitSeconds: Double = 60) async throws -> WeavePushResponse {
        let records = request.all
        guard !records.isEmpty else { throw WeaveHTTPError.status(400, "no text to file") }
        let client = try ThreadHTTPClient.forHome(endpoint.home, port: endpoint.threadHTTP)
        let group = group(thread: thread, label: request.group)
        let before = try await documents(in: group.id, client: client)
        let receipt = try await client.deposit(texts: records.map(\.text), names: records.map(\.name),
                                               groupID: group.id, groupLabel: group.label)
        guard receipt.success else { throw WeaveHTTPError.status(502, "the Thread did not accept the records") }
        // Searchable: each record's own text comes back from a search of the Thread. Not a count of the
        // group's documents: Thread files identical text once, so filing it again adds nothing to count.
        var indexed = false
        if request.wait ?? true {
            let deadline = Date().addingTimeInterval(waitSeconds)
            while Date() < deadline {
                if try await searchable(records.prefix(5).map(\.text), client: client) { indexed = true; break }
                try await TaskSleep.seconds(0.25)
            }
        }
        let count = max(before, try await documents(in: group.id, client: client))
        return WeavePushResponse(thread: thread, ownerId: WeaveIdentity.owner, group: group, filed: records.count,
                                 indexed: indexed, documents: count)
    }

    public static func search(_ request: WeaveThreadSearchRequest, thread: String, endpoint: ExplorerOps.Endpoint) async throws -> WeaveThreadSearchResponse {
        let client = try ThreadHTTPClient.forHome(endpoint.home, port: endpoint.threadHTTP)
        let response = try await client.search(request.query, topK: min(max(request.topK ?? 10, 1), 50))
        let hits = ThreadHit.zip(response).map {
            WeaveThreadHit(rank: $0.rank, text: $0.text, documentId: $0.reference.id, partitionId: $0.reference.partitionId)
        }
        return WeaveThreadSearchResponse(thread: thread, hits: hits)
    }

    public static func records(thread: String, endpoint: ExplorerOps.Endpoint) async throws -> WeaveRecordsResponse {
        let client = try ThreadHTTPClient.forHome(endpoint.home, port: endpoint.threadHTTP)
        let groups = try await client.library().map { WeaveRecordsResponse.Group(id: $0.id, label: $0.label, documents: $0.documents) }
        return WeaveRecordsResponse(thread: thread, ownerId: WeaveIdentity.owner, groups: groups)
    }

    /// Whether a search for each text finds it (its first words, as Thread stores the first chunk).
    static func searchable(_ texts: [String], client: ThreadHTTPClient) async throws -> Bool {
        for text in texts {
            let head = normalized(String(text.prefix(48)))
            let hits = try await client.search(String(text.prefix(300)), topK: 5).texts
            guard hits.contains(where: { normalized($0).hasPrefix(head) || normalized($0).contains(head) }) else { return false }
        }
        return true
    }

    static func normalized(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func documents(in groupID: String, client: ThreadHTTPClient) async throws -> Int {
        try await client.library().first { $0.id == groupID }?.documents.count ?? 0
    }
}
