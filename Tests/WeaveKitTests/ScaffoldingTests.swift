//
//  ScaffoldingTests.swift
//  WeaveKitTests
//

import Foundation
import Testing
@testable import WeaveKit

@Suite struct ScaffoldingTests {
    @Test func aTicketResolvedBeforeItIsAwaitedKeepsItsValue() async throws {
        let tickets = VeilTickets<Int>()
        let ticket = await tickets.open()
        await tickets.resolve(ticket.id, with: 7)
        #expect(try await tickets.wait(ticket.id) == 7)
    }

    @Test func aFailedTicketThrows() async {
        let tickets = VeilTickets<Int>()
        let ticket = await tickets.open()
        await tickets.fail(ticket.id, FabricError.noHost)
        await #expect(throws: FabricError.noHost) { try await tickets.wait(ticket.id) }
    }

    @Test func theLaneRunsBodiesInArrivalOrder() async throws {
        let lane = VeilLane()
        let order = TransientRegistry<Int>()
        async let a: Void = lane.run { try await Task.sleep(nanoseconds: 30_000_000); order.put("a", order.keys(prefix: "").count) }
        try await Task.sleep(nanoseconds: 5_000_000)
        async let b: Void = lane.run { order.put("b", order.keys(prefix: "").count) }
        _ = try await (a, b)
        #expect(order.get("a") == 0 && order.get("b") == 1)
    }

    @Test func theRegistryRemovesByPrefix() {
        let registry = TransientRegistry<Int>()
        registry.put("alpha/thread", 1); registry.put("alpha/sewn", 2); registry.put("beta/thread", 3)
        registry.removeAll(prefix: "alpha/")
        #expect(registry.keys(prefix: "") == ["beta/thread"])
    }

    @Test func aCancelBeforeRegisterLeavesATombstone() {
        let runs = RunRegistry()
        runs.cancel("run-1")
        #expect(!runs.register("run-1", Task {}))
    }
}
