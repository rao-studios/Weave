//
//  RequestExamplesTests.swift
//  WeaveKitTests
//

import Foundation
import Testing
@testable import WeaveKit

@Suite struct RequestExamplesTests {
    private func json(_ text: String?) -> [String: Any] {
        (text.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) } as? [String: Any]) ?? [:]
    }

    @Test func everyBodyIsTheAIIsOwnPlusTheRoutingSpec() {
        let examples = RequestExamples.all(thread: "beta")
        #expect(examples.map(\.kind) == RequestExample.Kind.allCases)
        let insert = examples.first { $0.kind == .insert }!
        #expect(insert.path == "/v1/batch/embeddings" && insert.body?.hasPrefix(#"{"weave": {"aii": "beta", "wait": true}"#) == true)
        let body = json(insert.body)
        #expect((body["inputs"] as? [String])?.count == 1 && body["entities"] != nil)
        #expect(json(insert.own?.json)["weave"] == nil, "the direct body is the same, without weave")
        let all = examples.first { $0.kind == .searchAll }!
        #expect(all.aii == nil && json(all.body)["sewn"] != nil && json(all.body)["weave"] == nil, "a search across every AII is Sewn's own body")
        #expect(examples.filter(\.direct).map(\.kind) == [.insert, .searchOne, .library, .graph])
    }

    @Test func curlCarriesTheKeyOnlyWhenThePortAsks() {
        let insert = RequestExamples.all(thread: "alpha").first { $0.kind == .insert }!
        let gated = RequestExamples.code(insert, format: .curl, port: 47600, requireSecret: true)
        #expect(gated.contains("X-Ambient-Secret: $(cat ~/.rao/secrets/weave)") && gated.contains("http://127.0.0.1:47600/v1/batch/embeddings"))
        #expect(!RequestExamples.code(insert, format: .curl, port: 47600, requireSecret: false).contains("X-Ambient-Secret"))
    }

    @Test func swiftAndJavaScriptCallsForwardTheSameBody() {
        let search = RequestExamples.all(thread: "gamma").first { $0.kind == .searchOne }!
        let swift = RequestExamples.code(search, format: .swift, port: 47600, requireSecret: true)
        #expect(swift.contains(#"post("/v1/search", aii: "gamma", body: ["query": "punched cards""#))
        let js = RequestExamples.code(search, format: .javascript, port: 47600, requireSecret: true)
        #expect(js.contains(#"{"weave": {"aii": "gamma"}, "query": "punched cards""#))
        let client = RequestExamples.client(format: .swift, port: 47601, requireSecret: true)!
        #expect(client.contains("init(port: Int = 47601)") && client.contains("routed[\"weave\"]"))
        #expect(RequestExamples.client(format: .curl, port: 47600, requireSecret: true) == nil)
    }

    @Test func theDirectFormNamesTheThreadAndItsKey() {
        let library = RequestExamples.all(thread: "alpha").first { $0.kind == .library }!
        let line = RequestExamples.direct(library, url: "http://127.0.0.1:47611", keyFile: "/x/alpha/secrets/weave")!
        #expect(line.contains("POST http://127.0.0.1:47611/v1/library") && line.contains("/x/alpha/secrets/weave"))
        #expect(RequestExamples.direct(RequestExamples.all(thread: "alpha")[0], url: "u", keyFile: "k") == nil)
    }

    @Test func theRoutingSpecSplitsOffAndTheOwnerIsFilled() throws {
        let raw = Data(#"{"weave": {"aii": "alpha", "wait": true}, "owner_id": "x"}"#.utf8)
        let (routing, body) = try Forwarder.split(raw, header: nil, query: nil)
        #expect(routing == Forwarder.Routing(aii: "alpha", wait: true) && body?["weave"] == nil)
        #expect(try Forwarder.split(raw, header: "beta", query: "gamma").0.aii == "beta", "a header wins")
        var library: [String: Any] = [:]
        #expect(Forwarder.fillOwner(&library, path: "/v1/library") == WeaveIdentity.owner && library["owner_id"] as? String == WeaveIdentity.owner)
        #expect(Forwarder.inputs(["inputs": ["a", ["b", "c"]]]) == ["a", "b c"])
        #expect(ThreadGateway.ref("main") == .main && ThreadGateway.ref("alpha") == .spawned("alpha"))
    }
}
