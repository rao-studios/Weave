//
//  VeilTickets.swift
//  WeaveKit
//
//  A typed reply slot for a ticketed dispatch: a caller opens a ticket, sends a reducer the
//  ticket's id in its payload, and awaits the value the reducer's effect resolves it with.
//  Every stage of the pipeline answers this way, so the dispatch stays visible in the callee's
//  reducers and state while the caller gets a typed value back.
//

import Foundation

public actor VeilTickets<Value: Sendable> {
    public struct Ticket: Sendable, Hashable {
        public let id: UUID
    }

    private enum Slot {
        case open
        case waiting(CheckedContinuation<Value, any Error>)
        case settled(Result<Value, any Error>)
    }

    private var slots: [UUID: Slot] = [:]

    public init() {}

    /// Open before sending, so a resolve that lands before `wait` is kept, not lost.
    public func open() -> Ticket {
        let ticket = Ticket(id: UUID())
        slots[ticket.id] = .open
        return ticket
    }

    /// Suspends until the ticket is resolved or failed. Cancelling the waiting task cancels the
    /// ticket; the reducer's effect still runs to completion, and its late resolve is dropped.
    public func wait(_ id: UUID) async throws -> Value {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Value, any Error>) in
                switch slots[id] {
                case .settled(let result)?:
                    slots[id] = nil
                    continuation.resume(with: result)
                case .open?:
                    slots[id] = .waiting(continuation)
                case .waiting?:
                    continuation.resume(throwing: TicketError.alreadyAwaited(id))
                case nil:
                    continuation.resume(throwing: CancellationError())
                }
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    public func resolve(_ id: UUID, with value: Value) { settle(id, .success(value)) }
    public func fail(_ id: UUID, _ error: any Error) { settle(id, .failure(error)) }
    public func cancel(_ id: UUID) { settle(id, .failure(CancellationError())) }

    /// Open tickets nobody has settled yet (tests).
    public var pending: Int { slots.count }

    private func settle(_ id: UUID, _ result: Result<Value, any Error>) {
        switch slots[id] {
        case .waiting(let continuation)?:
            slots[id] = nil
            continuation.resume(with: result)
        case .open?:
            slots[id] = .settled(result)
        case .settled?, nil:
            break   // a second settle, or a cancelled ticket: dropped
        }
    }
}

public enum TicketError: Error, Equatable { case alreadyAwaited(UUID) }
