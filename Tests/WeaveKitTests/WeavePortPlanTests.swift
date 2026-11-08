//
//  WeavePortPlanTests.swift
//  WeaveKitTests
//

import Testing
@testable import WeaveKit

@Suite struct WeavePortPlanTests {
    @Test func aSlotOwnsFourPortsAboveWeavesOwn() {
        let slot = WeavePortPlan.slot(1)
        #expect(slot.ports == [47611, 47612, 47613, 47614])
        #expect(WeavePortPlan.slot(39).sewnGRPC == 47994)
    }

    @Test func noSlotTouchesTheMainStackOrTheReservedPorts() {
        let main: Set<Int> = [AIIPortPlan.sewn.http, AIIPortPlan.sewn.grpc, AIIPortPlan.thread.http, AIIPortPlan.thread.grpc, WeaveIdentity.defaultPort]
        for index in WeavePortPlan.slots {
            let ports = Set(WeavePortPlan.slot(index).ports)
            #expect(ports.isDisjoint(with: main))
            #expect(ports.isDisjoint(with: AIIPortPlan.reservedElsewhere))
        }
    }

    @Test func theFreeSlotSkipsTakenAndListeningPorts() {
        let taken = Set(WeavePortPlan.slot(1).ports)
        let slot = WeavePortPlan.freeSlot(taken: taken, listening: { $0 == WeavePortPlan.slot(2).threadGRPC })
        #expect(slot?.index == 3)
    }

    @Test func everySlotTakenAnswersNone() {
        #expect(WeavePortPlan.freeSlot(taken: [], listening: { _ in true }) == nil)
    }
}
