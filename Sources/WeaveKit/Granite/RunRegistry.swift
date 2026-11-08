//
//  RunRegistry.swift
//  WeaveKit
//
//  Cancellable work by id. A Granite effect's `.run` hands out no Task and nothing cancels an
//  in-flight reducer, so long work makes its own Task and registers it here; a cancel reducer
//  cancels it. A cancel that arrives before the register leaves a tombstone, and `register`
//  then returns false so the caller cancels the Task at once.
//

import Foundation

public final class RunRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [String: Task<Void, Never>] = [:]
    private var cancelled: Set<String> = []

    public init() {}

    @discardableResult
    public func register(_ id: String, _ task: Task<Void, Never>) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if cancelled.contains(id) { return false }
        tasks[id] = task
        return true
    }

    public func cancel(_ id: String) {
        lock.lock(); defer { lock.unlock() }
        if let task = tasks[id] { task.cancel() }
        cancelled.insert(id)
    }

    public func isCancelled(_ id: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled.contains(id)
    }

    public func isRunning(_ id: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return tasks[id] != nil
    }

    public func finish(_ id: String) {
        lock.lock(); tasks[id] = nil; cancelled.remove(id); lock.unlock()
    }
}
