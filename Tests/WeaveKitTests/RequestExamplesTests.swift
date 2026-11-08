//
//  RequestExamplesTests.swift
//  WeaveKitTests
//

import Foundation
import Testing
@testable import WeaveKit

@Suite struct RequestExamplesTests {
    @Test func everyExampleNamesTheChosenAII() {
        let examples = RequestExamples.all(thread: "beta")
        #expect(examples.map(\.kind) == RequestExample.Kind.allCases)
        let insert = examples.first { $0.kind == .insert }!
        #expect(insert.method == "POST" && insert.path == "/v1/records")
        #expect(insert.body?.hasPrefix(#"{"thread": "beta""#) == true)
        #expect(examples.first { $0.kind == .searchOne }!.body?.contains(#""thread": "beta""#) == true)
        #expect(examples.first { $0.kind == .searchAll }!.body?.contains("thread") == false)
        #expect(examples.first { $0.kind == .records }!.path == "/v1/threads/beta/records")
    }

    @Test func curlCarriesTheKeyOnlyWhenThePortAsks() {
        let insert = RequestExamples.all(thread: "alpha").first { $0.kind == .insert }!
        let gated = RequestExamples.code(insert, format: .curl, port: 47600, requireSecret: true)
        #expect(gated.contains("X-Ambient-Secret: $(cat ~/.rao/secrets/weave)") && gated.contains("http://127.0.0.1:47600/v1/records"))
        #expect(!RequestExamples.code(insert, format: .curl, port: 47600, requireSecret: false).contains("X-Ambient-Secret"))
    }

    @Test func theClientsUseThePortAndThreadsAreNamedInCalls() {
        let swift = RequestExamples.client(format: .swift, port: 47601, requireSecret: true)!
        #expect(swift.contains("final class WeaveService") && swift.contains("init(port: Int = 47601)") && swift.contains(".rao/secrets/weave"))
        #expect(RequestExamples.client(format: .curl, port: 47600, requireSecret: true) == nil)
        let js = RequestExamples.client(format: .javascript, port: 47600, requireSecret: false)!
        #expect(js.contains("const key = null") && js.contains("export async function weave"))
        let call = RequestExamples.code(RequestExamples.all(thread: "gamma")[1], format: .swift, port: 47600, requireSecret: true)
        #expect(call.contains(#"into: "gamma""#))
    }

    @Test func aGroupLabelBecomesTheAIIsOwnGroupID() {
        #expect(ThreadGateway.group(thread: "alpha", label: "Field Notes!").id == "weave-alpha-field-notes")
        #expect(ThreadGateway.group(thread: "alpha", label: nil).id == "weave-alpha")
        #expect(ThreadGateway.group(thread: "main", label: nil).id == "weave-main")
        #expect(ThreadGateway.ref("main") == .main && ThreadGateway.ref("alpha") == .spawned("alpha"))
    }
}
