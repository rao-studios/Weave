//
//  OpsTests.swift
//  WeaveKitTests
//
//  Every service's transitions, as pure functions.
//

import Foundation
import Testing
import WeaveKitTestSupport
@testable import WeaveKit

@Suite struct FabricOpsTests {
    @Test func aScanReplacesTheThreadsAndDropsWhatLeft() {
        var state = FabricService.Center.State()
        state.status["gone"] = .up(pid: 1)
        state.counts["gone"] = ThreadCounts(documents: 1, groups: 1, entities: 0, relationships: 0)
        let scan = FabricScan(root: "/r", fingerprint: "abcd1234", records: [Fixtures.record("beta", slot: 2), Fixtures.record("alpha")],
                              shapes: [:], reseed: ["beta"], serverBinary: "/bin/AIIServer", serverInstalled: true, legacyNote: nil)
        FabricOps.apply(.scanned(scan), to: &state)
        #expect(state.threads.map(\.name) == ["alpha", "beta"])
        #expect(state.status["gone"] == nil && state.counts["gone"] == nil)
        #expect(state.reseed == ["beta"] && state.scanned && !state.scanning)
    }

    @Test func aProbeLeavesABusyInstancesStatusToItsVerb() {
        var state = FabricService.Center.State()
        let ticket = UUID()
        FabricOps.adopt(ticket, for: "alpha", in: &state)
        state.status["alpha"] = .starting
        FabricOps.apply(.probe("alpha", ThreadProbe(status: .stopped(nil), embedder: nil, extractor: "ready",
                                                    counts: ThreadCounts(documents: 3, groups: 1, entities: 2, relationships: 1))), to: &state)
        #expect(state.status["alpha"] == .starting)
        #expect(state.counts["alpha"]?.documents == 3 && state.extractor["alpha"] == "ready")
        FabricOps.apply(.idle("alpha"), to: &state)
        FabricOps.apply(.probe("alpha", ThreadProbe(status: .up(pid: 9), embedder: nil, extractor: nil, counts: nil)), to: &state)
        #expect(state.status["alpha"] == .up(pid: 9))
    }

    @Test func aSecondVerbIsNotAdoptedWhileTheFirstRuns() {
        var state = FabricService.Center.State()
        let first = UUID(), second = UUID()
        FabricOps.adopt(first, for: "alpha", in: &state)
        FabricOps.adopt(second, for: "alpha", in: &state)
        #expect(state.busy["alpha"] == first)
    }

    @Test func removingForgetsEverything() {
        var state = FabricService.Center.State()
        FabricOps.apply(.record(Fixtures.record("alpha")), to: &state)
        FabricOps.apply(.status("alpha", .up(pid: 2)), to: &state)
        FabricOps.apply(.removed("alpha"), to: &state)
        #expect(state.threads.isEmpty && state.status.isEmpty)
    }

    @Test func aRecordIsReplacedInPlace() {
        var state = FabricService.Center.State()
        FabricOps.apply(.record(Fixtures.record("alpha")), to: &state)
        FabricOps.apply(.record(Fixtures.record("alpha", woven: false)), to: &state)
        #expect(state.threads.count == 1 && state.threads[0].woven == false)
        #expect(state.takenPorts == Set(WeavePortPlan.slot(1).ports))
    }
}

@Suite struct HostOpsTests {
    @Test func selectingClearsTheOldNodes() {
        var state = HostService.Center.State()
        HostOps.apply(.nodes([Fixtures.node("a", httpPort: 47081)], Date()), to: &state)
        let target = HostTarget(selection: .spawned("alpha"), homeRoot: "/a", sewnPorts: WeavePortPlan.slot(1).sewnPorts, threadPorts: WeavePortPlan.slot(1).threadPorts)
        HostOps.apply(.selected(.spawned("alpha"), target), to: &state)
        #expect(state.nodes.isEmpty && state.target == target && state.selection == .spawned("alpha"))
    }

    @Test func aSpawnedHostResolvesToItsSlotsSewn() throws {
        var fabric = FabricService.Center.State()
        fabric.threads = [Fixtures.record("alpha", slot: 3)]
        let target = try HostOps.resolve(.spawned("alpha"), fabric: fabric)
        #expect(target.sewnPorts == AIIPorts(http: 47633, grpc: 47634))
        #expect(throws: FabricError.notFound("nope")) { try HostOps.resolve(.spawned("nope"), fabric: fabric) }
    }

    @Test func nodesAreNamedByTheirThreadsPort() {
        let records = [Fixtures.record("alpha")]
        #expect(HostOps.name(of: Fixtures.node("x", httpPort: 47611), records: records, mainThreadHTTP: 47081) == "alpha")
        #expect(HostOps.name(of: Fixtures.node("y", httpPort: 47081, app: "aii"), records: records, mainThreadHTTP: 47081) == "main AII")
        #expect(HostOps.name(of: Fixtures.node("z", httpPort: 9), records: records, mainThreadHTTP: 47081) == nil)
    }
}

@Suite struct SearchOpsTests {
    @Test func aLateAnswerToAnOlderQueryIsDropped() {
        var state = SearchService.Center.State()
        state.epoch = 2
        SearchOps.apply(.results([], nil, latencyMs: 1, epoch: 1), to: &state)
        state.searching = true
        SearchOps.apply(.results([], nil, latencyMs: 1, epoch: 1), to: &state)
        #expect(state.searching)
        SearchOps.apply(.failed("boom", epoch: 2), to: &state)
        #expect(!state.searching && state.lastError == "boom")
    }

    @Test func mergedHitsAreNamedByTheInstanceThatAnswered() throws {
        let response = try LoopbackHTTP.decoder.decode(SewnSearchResponse.self, from: Data(Fixtures.sewnSearchJSON.utf8))
        let nodes = [Fixtures.node("aaa", httpPort: 47611), Fixtures.node("BBB", httpPort: 47081, app: "aii")]
        let hits = SearchOps.hits(response, nodes: nodes, records: [Fixtures.record("alpha")], mainThreadHTTP: 47081)
        #expect(hits.map(\.threadName) == ["alpha", "main AII"])
        #expect(hits.map(\.rank) == [1, 2])
        var state = SearchService.Center.State()
        state.epoch = 1
        SearchOps.apply(.results(hits, response.graph, latencyMs: 4, epoch: 1), to: &state)
        #expect(state.answeredBy == ["alpha", "main AII"])
    }

    @Test func aRefusalWithoutAnAccountSaysWhatToInstall() {
        #expect(SearchOps.explain(WeaveHTTPError.status(401, "")).contains("POST /v1/search"))
        #expect(SearchOps.explain(FabricError.noHost).contains("No host"))
    }
}

@Suite struct PortOpsTests {
    @Test func threadsJoinTheHostsNodesByPort() {
        var fabric = FabricService.Center.State()
        fabric.threads = [Fixtures.record("alpha"), Fixtures.record("beta", slot: 2, woven: false)]
        fabric.status["alpha"] = .up(pid: 3)
        fabric.counts["alpha"] = ThreadCounts(documents: 5, groups: 1, entities: 0, relationships: 0)
        var host = HostService.Center.State()
        host.nodes = [Fixtures.node("n1", httpPort: 47611)]
        let threads = PortOps.threads(PortOps.Snapshot(port: 47600, host: host, fabric: fabric))
        #expect(threads.ownerId == WeaveIdentity.owner)
        #expect(threads.threads.map(\.id) == ["alpha", "beta", "main"], "every spawned AII, then the main AII")
        #expect(threads.threads[0].node?.threadId == "n1" && threads.threads[0].documents == 5 && threads.threads[0].status == "up")
        #expect(threads.threads[0].accepting && !threads.threads[1].accepting)
        #expect(threads.threads[1].node == nil && !threads.threads[1].woven)
        #expect(threads.threads[2].label == "main AII" && threads.insert.contains("/v1/records"))
    }

    @Test func aReplacedServersLateWriteIsDropped() {
        var state = PortService.Center.State()
        state.generation = 2
        PortOps.apply(.listening(true, generation: 1), to: &state)
        #expect(!state.listening)
        PortOps.apply(.listening(true, generation: 2), to: &state)
        #expect(state.listening)
    }
}

@Suite struct ExplorerOpsTests {
    @Test func selectingAnotherThreadClearsWhatWasRead() {
        var state = ExplorerService.Center.State()
        ExplorerOps.apply(.selected(.spawned("alpha")), to: &state)
        ExplorerOps.apply(.library(.spawned("alpha"), [LibraryGroup(id: "g", label: "G", ownerId: "o", documents: [])]), to: &state)
        #expect(state.library.count == 1)
        ExplorerOps.apply(.selected(.main), to: &state)
        #expect(state.library.isEmpty && state.selected == .main)
    }

    @Test func anAnswerForAnotherThreadIsDropped() {
        var state = ExplorerService.Center.State()
        ExplorerOps.apply(.selected(.main), to: &state)
        state.loading = [.search]
        ExplorerOps.apply(.hits(.spawned("alpha"), []), to: &state)
        #expect(state.loading == [.search])
        ExplorerOps.apply(.failed(.main, .search, "nope"), to: &state)
        #expect(state.loading.isEmpty && state.errors[.search] == "nope")
    }

    @Test func depositsGoToTheThreadsOwnGroup() {
        #expect(ExplorerOps.depositGroup(.spawned("alpha")).id == "weave-alpha")
        #expect(ExplorerOps.depositGroup(.main).id == "weave-main")
    }

    @Test func theLogTailKeepsTheLastLines() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("weave-log-\(UUID()).log")
        defer { try? FileManager.default.removeItem(at: url) }
        try (1...300).map { "line \($0)" }.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        let tail = ExplorerOps.tail(url, lines: 5)
        #expect(tail == ["line 296", "line 297", "line 298", "line 299", "line 300"])
    }
}
