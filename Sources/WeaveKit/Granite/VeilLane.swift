//
//  VeilLane.swift
//  WeaveKit
//
//  A serial async queue: bodies run one after another in arrival order. The one GPU model, the
//  one Thread write path and one layer check at a time each go through a lane, because Granite's
//  effects run concurrently and nothing else would serialize them. Cancelling a caller cancels
//  its own body; the rest of the queue is unaffected.
//

public actor VeilLane {
    private var tail: Task<Void, Never>?

    public init() {}

    public func run<T: Sendable>(_ body: @escaping @Sendable () async throws -> T) async throws -> T {
        let previous = tail
        let task = Task<T, any Error> {
            await previous?.value
            try Task.checkCancellation()
            return try await body()
        }
        tail = Task { _ = try? await task.value }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
