//
//  WireTests.swift
//  WeaveKitTests
//
//  What the clients send and how they read what Thread and Sewn answer.
//

import Foundation
import Testing
import WeaveKitTestSupport
@testable import WeaveKit

@Suite struct WireTests {
    @Test func theLibraryDecodesEitherDateForm() throws {
        let response = try LoopbackHTTP.decoder.decode(LibraryResponse.self, from: Data(Fixtures.libraryJSON.utf8))
        let documents = response.groups[0].documents
        #expect(documents.count == 2 && documents[0].name == "note")
        #expect(documents[0].createdAt != nil && documents[1].createdAt != nil)
    }

    @Test func aDepositIsFiledAsWeavesOwnerInTheThreadsGroup() async throws {
        let stub = StubTransport(body: #"{"object":"list","success":true,"model":"voyage"}"#)
        let client = ThreadHTTPClient(port: 47611, secret: "s", transport: stub.transport)
        let receipt = try await client.deposit("hello", name: "n", groupID: "weave-alpha", groupLabel: "Weave · alpha")
        #expect(receipt.success)
        let request = try #require(stub.asked.first)
        #expect(request.url?.absoluteString == "http://127.0.0.1:47611/v1/batch/embeddings")
        #expect(request.value(forHTTPHeaderField: StackSecret.headerName) == "s")
        let body = try #require(request.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        let thread = try #require(body["thread"] as? [String: Any])
        #expect(thread["owner_id"] as? String == WeaveIdentity.owner)
        #expect((thread["group"] as? [String: Any])?["id"] as? String == "weave-alpha")
        #expect(body["sanitize"] as? Bool == true)
    }

    @Test func theFederatedSearchAsksForTopKAsWeave() throws {
        let body = try #require(JSONSerialization.jsonObject(with: SewnHTTPClient.body(query: "q", topK: 12)) as? [String: Any])
        #expect(body["top_k"] as? Int == 12)
        #expect((body["sewn"] as? [String: Any])?["owner_id"] as? String == WeaveIdentity.owner)
    }

    @Test func aRefusalCarriesItsStatus() async {
        let stub = StubTransport(status: 401, body: "Missing bearer")
        let client = SewnHTTPClient(port: 47080, secret: "s", transport: stub.transport)
        await #expect(throws: WeaveHTTPError.status(401, "Missing bearer")) { try await client.search("q") }
    }

    @Test func nothingLeavesThisMac() async {
        let request = URLRequest(url: URL(string: "http://example.com/v1/search")!)
        await #expect(throws: WeaveHTTPError.notLoopback) { try await LoopbackHTTP.send(request) }
    }
}
