//
//  TransientRegistry.swift
//  WeaveKit
//
//  The residents a Granite state cannot hold (executors, backends, embedders, frames, images,
//  Tasks), kept by key; the state carries the key, a count or a revision. Lock-based rather than
//  an actor so a synchronous reducer can read it on main.
//

import Foundation

public final class TransientRegistry<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: Value] = [:]

    public init() {}

    public func put(_ key: String, _ value: Value) {
        lock.lock(); items[key] = value; lock.unlock()
    }

    public func get(_ key: String) -> Value? {
        lock.lock(); defer { lock.unlock() }
        return items[key]
    }

    @discardableResult
    public func remove(_ key: String) -> Value? {
        lock.lock(); defer { lock.unlock() }
        return items.removeValue(forKey: key)
    }

    public func contains(_ key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return items[key] != nil
    }

    public func keys(prefix: String = "") -> [String] {
        lock.lock(); defer { lock.unlock() }
        return items.keys.filter { $0.hasPrefix(prefix) }.sorted()
    }

    public func removeAll(prefix: String) {
        lock.lock(); items = items.filter { !$0.key.hasPrefix(prefix) }; lock.unlock()
    }

    public func removeAll() {
        lock.lock(); items.removeAll(); lock.unlock()
    }
}
