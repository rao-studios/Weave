//
//  FabricService.Work.swift
//  WeaveKit
//
//  The one shape every verb's effect takes: go on only when `reduce` adopted this request for the
//  instance, do the work, free the instance, and answer the ticket.
//

import Foundation
import Granite

extension FabricService {
    /// Call from a verb's `effect` (main).
    static func work(ticket: UUID, name: String, state: Center.State,
                     _ body: @escaping @Sendable (FabricService) async throws -> Reply) -> GraniteEffect {
        guard state.busy[name] == ticket else {
            return .run { await FabricService.tickets.fail(ticket, FabricError.busy(name)) }
        }
        let fabric = Live.service(FabricService.self)
        return .run {
            do {
                let reply = try await body(fabric)
                fabric.set(.idle(name))
                await MainQueue.flush()
                await FabricService.tickets.resolve(ticket, with: reply)
            } catch {
                fabric.set(.idle(name))
                fabric.set(.failed("\(name): \(FabricOps.message(error))"))
                await MainQueue.flush()
                await FabricService.tickets.fail(ticket, error)
            }
        }
    }
}
